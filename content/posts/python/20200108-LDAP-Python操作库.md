---
title: LDAP Python 操作库（ldap3）
categories:
  - Python
tags:
  - Python
  - 安全
date: 2020-02-09 00:00:00
top: false
comments: true
---

# 重要

`ldap3` 是 Python 操作 LDAP 的标准库。本文封装了常用操作类：连接、添加 OU/用户、查询、修改、删除（含递归删除子节点）。

# 环境说明

- Python 3.7
- ldap3

## 1. 安装

```bash
pip install ldap3
```

## 2. 完整工具类

```python
from ldap3 import Server, Connection, SUBTREE, ALL_ATTRIBUTES
from ldap3.core.exceptions import LDAPBindError
from ldap3 import MODIFY_REPLACE
from ldap3.utils.dn import safe_rdn

class LDAP(object):
    def __init__(self, host, port, user, password, base_dn):
        dn = "cn=%s,%s" % (user, base_dn)
        self.server = Server(host=host, port=port)
        self.base_dn = base_dn
        self.__conn = Connection(self.server, dn, password, auto_bind=True)

    def add_ou(self, ou, oid):
        """添加 OU，oid 保存至 st 字段"""
        return self.__conn.add(ou, 'organizationalUnit', {"st": oid})

    def add_user(self, userid, username, mobile, mail, title, ou_dn, gidnumber=501):
        """添加用户
        :param userid: 用户 ID（如 "linan"）
        :param username: 姓名（cn）
        :param ou_dn: 如 "ou=运维中心,dc=domain,dc=com"
        """
        objectclass = ['top', 'person', 'inetOrgPerson', 'posixAccount']
        add_dn = "cn=%s,%s" % (username, ou_dn)
        password = '%s@qwe' % userid
        return self.__conn.add(add_dn, objectclass, {
            'mobile': mobile, 'sn': userid, 'mail': mail,
            'userPassword': password, 'title': title, 'uid': username,
            'gidNumber': gidnumber,
            'uidNumber': userid.strip("xxx"),
            'homeDirectory': '/home/users/%s' % userid,
            'loginShell': '/bin/bash',
        })

    def get_userdn_by_mail(self, mail, base_dn=None):
        """通过邮箱查询用户 entry"""
        status = self.__conn.search(
            base_dn or self.base_dn,
            search_filter='(mail={})'.format(mail),
            search_scope=SUBTREE, attributes=ALL_ATTRIBUTES)
        return self.__conn.entries[0] if status and self.__conn.entries else False

    def get_userdn_by_args(self, base_dn=None, **kwargs):
        """多条件查询用户（& 逻辑），支持任意 LDAP 属性"""
        search = "".join("(%s=%s)" % (k, v) for k, v in kwargs.items())
        search_filter = '(&%s)' % search if search else ''
        status = self.__conn.search(
            base_dn or self.base_dn,
            search_filter=search_filter,
            search_scope=SUBTREE, attributes=ALL_ATTRIBUTES)
        return self.__conn.entries if status and self.__conn.entries else False

    def authenticate_userdn_by_mail(self, mail, password):
        """验证用户密码"""
        entry = self.get_userdn_by_mail(mail=mail)
        if not entry:
            return False
        try:
            Connection(self.server, entry.entry_dn, password, auto_bind=True)
            return True
        except LDAPBindError:
            return False

    def update_user_info(self, user_dn, action=MODIFY_REPLACE, **kwargs):
        """修改用户属性（uid, mail, sn, mobile, title 等）"""
        allow_key = "uid userPassword mail sn gidNumber uidNumber mobile title".split()
        update_args = {}
        for k, v in kwargs.items():
            if k not in allow_key:
                return False
            update_args[k] = [(action, [v])]
        return self.__conn.modify(user_dn, update_args)

    def update_user_cn(self, user_dn, new_cn):
        """修改用户 CN"""
        return self.__conn.modify_dn(user_dn, 'cn=%s' % new_cn)

    def update_ou(self, dn, new_ou_dn):
        """移动用户到新 OU"""
        rdn = safe_rdn(dn)
        return self.__conn.modify_dn(dn, rdn[0], new_superior=new_ou_dn)

    def delete_dn(self, dn):
        """删除 DN，如果是 OU 则递归删除子节点"""
        if not dn.startswith("cn"):
            all_users = self.get_userdn_by_args(base_dn=dn, objectClass="Person")
            if all_users:
                for u in all_users:
                    self.__conn.delete(u.entry_dn)
            all_ous = self.get_userdn_by_args(base_dn=dn, objectClass="organizationalUnit")
            if all_ous:
                for ou in reversed(all_ous):
                    self.__conn.delete(ou.entry_dn)
        return self.__conn.delete(dn)
```

## 3. 使用示例

```python
ldap_config = {
    'host': "10.12.0.23",
    'port': 32616,
    'base_dn': 'dc=service,dc=corp',
    'user': 'admin',
    'password': 'xxxxxx',
}
ldap = LDAP(**ldap_config)

# 添加组织单元
ldap.add_ou("ou=研发中心,dc=service,dc=corp", 1)

# 添加用户
ldap.add_user("linan", "李南", "190283812", "linan@domain.com",
              "运维", ou_dn="ou=运维中心,dc=service,dc=corp")

# 验证密码
ldap.authenticate_userdn_by_mail("linan@domain.com", "xxx9999@qwe")

# 多条件查询
entries = ldap.get_userdn_by_args(cn="李南", mail="linan@domain.com")
```

## 参考

- [ldap3 官方文档](https://ldap3.readthedocs.io/)
