---
title: LDAP-Python 操作库
categories:
  - Python
tags:
  - Python
  - LDAP
date: '2020-01-08 03:05:07'
top: false
comments: true
---
运行环境
python环境: python3.7

安装包
```bash
pip install ldap3
```

```python
#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
@Time    : 2019/11/14 5:37 PM
@Author  : Hex
@File    : ldapBaseApi.py
@Software: PyCharm
# ApiDocument: https://ldap3.readthedocs.io/
# https://ldap3.readthedocs.io/tutorial_operations.html#
"""
# import sys
# reload(sys)
# sys.setdefaultencoding('utf8')
from ldap3 import Server, Connection, SUBTREE, ALL_ATTRIBUTES
from ldap3.core.exceptions import LDAPBindError
from ldap3 import MODIFY_REPLACE
from ldap3.utils.dn import safe_rdn
from rest_framework.exceptions import APIException


class LDAP(object):
    def __init__(self, host, port, user, password, base_dn):
        dn = "cn=%s,%s" % (user, base_dn)
        self.server = Server(host=host, port=port)
        self.base_dn = base_dn
        self.__conn = Connection(self.server, dn, password, auto_bind=True)

    def add_ou(self, ou, oid):
        """
        参考: https://ldap3.readthedocs.io/tutorial_operations.html#create-an-entry
        添加oy
        :param ou: 'ou=测试部,dc=domain,dc=com' 或者 'ou=测试子部门,ou=测试部,dc=domain,dc=com'
        :param oid: 部门id保存至st中
        :return:
        """
        return self.__conn.add(ou, 'organizationalUnit', {"st": oid})

    def add_user(self, userid, username, mobile, mail, title, ou_dn, gidnumber=501, alias=None):
        """
        参考: https://ldap3.readthedocs.io/tutorial_operations.html#create-an-entry
        :param userid:     "linan"
        :param username:   "姓名" cn=姓名
        :param mobile:
        :param mail:       "xxx@domain.com"
        :param title:
        :param ou_dn:     "ou=运维中心,dc=domain,dc=com"
        :param gidnumber: 501 默认用户组
        :return:
        """
        l = self.__conn
        objectclass = ['top', 'person', 'inetOrgPerson', 'posixAccount']
        add_dn = "cn=%s,%s" % (username, ou_dn)

        # 也可以随机生成,我先随便写一个值，这个需要自己定义规则
        password = '%s@qwe' % userid
        uidNumber = '%s' % userid.strip("xxx")
        # 添加用户
        s = l.add(add_dn, objectclass, {'mobile': mobile,
                                        'sn': userid,
                                        'mail': mail,
                                        'userPassword': password,
                                        'title': title,
                                        'uid': username,
                                        'gidNumber': gidnumber,
                                        'uidNumber': uidNumber,
                                        'homeDirectory': '/home/users/%s' % userid,
                                        'loginShell': '/bin/bash'
                                        })
        return s

    def get_oudn_by_st(self, st, base_dn=None):
        """
        根据 st值 获取组织dn
        参考: https://ldap3.readthedocs.io/tutorial_searches.html
        :param base_dn:
        :param st:  部门id
        :return: entry
        """
        if not base_dn:
            base_dn = self.base_dn
        # 查询ou 中 返回的信息 attribute 包含 st
        status = self.__conn.search(base_dn, '(objectclass=organizationalUnit)', attributes=["st"])
        if status:
            flag = False
            for i in self.__conn.entries:
                if st:
                    if st in i.entry_attributes_as_dict["st"]:
                        return i
            else:
                return False
        else:
            return False

    def get_object_classes_info(self, objec_classes):
        """
        获取 Ldap中 object_classes的必要参数以及其他信息
        参考: https://ldap3.readthedocs.io/tutorial_searches.html
        :param objec_classes: objec_classes
        :return:
        """
        print(self.server.schema.object_classes[objec_classes])

    def get_userdn_by_mail(self, mail, base_dn=None):
        """
        通过邮箱地址，获取用户dn。部分没有邮箱地址的用户被忽略，不能使用ldap认证
        参考: https://ldap3.readthedocs.io/tutorial_searches.html
        :param mail:
        :param base_dn:
        :return:
        """
        if not base_dn:
            base_dn = self.base_dn
        status = self.__conn.search(base_dn,
                                    search_filter='(mail={})'.format(mail),
                                    search_scope=SUBTREE,
                                    attributes=ALL_ATTRIBUTES,
                                    )
        if status:
            flag = False
            for i in self.__conn.entries:
                # print(i.entry_dn)
                return i
            else:
                return False
        else:
            return False

    def get_userdn_by_args(self, base_dn=None, **kwargs):
        """
        参考: https://ldap3.readthedocs.io/tutorial_searches.html
        获取用户dn, 通过 args
        可以支持多个参数: get_userdn_by_args(mail="xxx@domain.com", uid="姓名")
        会根据 kwargs 生成 search的内容，进行查询: 多个条件是 & and查询
        返回第一个查询到的结果,
        建议使用唯一标识符进行查询
        这个函数基本可以获取所有类型的数据
        :param base_dn:
        :param kwargs:
        :return:
        """
        search = ""
        for k, v in kwargs.items():
            search += "(%s=%s)" % (k, v)
        if not base_dn:
            base_dn = self.base_dn
        if search:
            search_filter = '(&{})'.format(search)
        else:
            search_filter = ''
        status = self.__conn.search(base_dn,
                                    search_filter=search_filter,
                                    search_scope=SUBTREE,
                                    attributes=ALL_ATTRIBUTES
                                    )

        if status:
            return self.__conn.entries
        else:
            return False

    def authenticate_userdn_by_mail(self, mail, password):
        """
        验证用户名密码
        通过邮箱进行验证密码
        :param mail:
        :param password:
        :return:
        """

        entry = self.get_userdn_by_mail(mail=mail)

        if entry:
            bind_dn = entry.entry_dn
            try:
                Connection(self.server, bind_dn, password, auto_bind=True)
                return True
            except LDAPBindError:
                return False

        else:
            print("user: %s not exist! " % mail)
            return False

    def update_user_info(self, user_dn, action=MODIFY_REPLACE, **kwargs):
        """

        :param dn: 用户dn 可以通过get_userdn_by_args，get_userdn_by_mail 获取
        :param action: MODIFY_REPLACE 对字段原值进行替换  MODIFY_ADD 在指定字段上增加值   MODIFY_DELETE 对指定字段的值进行删除
        :param kwargs: 要进行变更的信息内容 uid userPassword mail sn gidNumber uidNumber mobile title
        :return:
        """
        allow_key = "uid userPassword mail sn gidNumber uidNumber mobile title".split(" ")
        update_args = {}
        for k, v in kwargs.items():
            if k not in allow_key:
                msg = "字段: %s, 不允许进行修改, 不生效" % k
                print(msg)
                return False
            update_args.update({k: [(action, [v])]})
        print(update_args)
        status = self.__conn.modify(user_dn, update_args)
        return status

    def update_user_cn(self, user_dn, new_cn):
        """
        修改cn

        dn: cn=用户,ou=运维部,ou=研发中心,dc=domain,dc=com
        rdn就是 cn=用户
        Example:
            from ldap3.utils.dn import safe_rdn
            safe_rdn('cn=b.smith,ou=moved,ou=ldap3-tutorial,dc=demo1,dc=freeipa,dc=org')
            [cn=b.smith]

        :param dn:
        :param new_cn:
        :return:
        """
        s = self.__conn.modify_dn(user_dn, 'cn=%s' % new_cn)
        return s

    def update_ou(self, dn, new_ou_dn):
        """
        更换所在的OU
        :param dn: 要进行变动的DN
        :param new_ou_dn:  新的OU DN
        :return:
        """
        rdn = safe_rdn(dn)
        print(rdn)
        s = self.__conn.modify_dn(dn, rdn[0], new_superior=new_ou_dn)
        return s

    def delete_dn(self, dn):
        """
        要进行删除的DN
        :param dn:
        :return:
        """
        # 如果不是以cn开头的需要清理(删除) sub-link
        if not dn.startswith("cn"):
            # 获取dn 下所有 sub Person DN 进行删除
            allUserEntry = self.get_userdn_by_args(base_dn=dn, objectClass="Person")
            if allUserEntry:
                for userentry in allUserEntry:
                    self.__conn.delete(userentry.entry_dn)
                    print("deleting ou %s and delete sub Person DN: %s" % (dn, userentry.entry_dn))
            # 获取dn 下所有 sub    OU进行删除
            allOuEntry = self.get_userdn_by_args(base_dn=dn, objectClass="organizationalUnit")
            if allOuEntry:
                for ouEntry in reversed(allOuEntry):
                    s = self.__conn.delete(ouEntry.entry_dn)
                    print("deleting ou %s and delete sub organizationalUnit DN: %s" % (dn, ouEntry.entry_dn))
        else:
            s = self.__conn.delete(dn)
        # print(self.__conn.result)
        return s


if __name__ == '__main__':
    ldap_config = {
        'host': "10.12.0.23",
        'port': 32616,
        'base_dn': 'dc=service,dc=corp',
        'user': 'admin',
        'password': 'xxxxxx',
    }

    ldapObj = LDAP(**ldap_config)
    # 同步企业微信 组织架构 to Ldap
    # 同步企业微信 User  To ldap
    # -------------------------------
    # 删除DN, 对DN下的 sub 进行递归删除
    # s = ldapObj.get_oudn_by_st("1")
    # status = ldapObj.delete_dn(s.entry_dn)
    # print(status)
    # -------------------------------
    # 验证用户密码
    # s = ldapObj.authenticate_userdn_by_mail("linan@domain.com", "xxx9999@qwe")
    # - -----------------------------
    # 添加用户
    # s = ldapObj.add_user("xxx9999", "李南", "190283812", "linan@domain.com", "运维",
    #                  ou_dn="ou=运维中心,dc=domain,dc=com")
    # --------------------------------
    # 查询 ou st  组id
    # s = obj.get_oudn_by_st(st="1")
    # --------------------------------
    # 添加OU
    # obj.add_ou("ou=总部,dc=domain,dc=com", 1)
    # obj.add_ou("ou=研发中心,ou=总部,dc=domain,dc=com", 2)
    # --------------------------------
    # 查询用户是否存在 - 通过 mail  获取用户 dn_entry
    # ldapObj.get_userdn_by_mail(mail="linan@domain.com")
    # --------------------------------
    # 根据 参数 查询用户DN   data = [dn_entry, ...] ，多个参数为 &
    # data = ldapObj.get_userdn_by_args(cn="李南",mail="xxxx")
    # --------------------------------
    # 对指定dn 进行参数修改  多个参数可以一起修改
    # s = ldapObj.update_user_info(data[0].entry_dn, userPassword="123456")
    # --------------------------------
    # 对指定DN 变更 OU-DN
    # s = ldapObj.update_user_ou(data[0].entry_dn, s.entry_dn)
    # --------------------------------
    # 对指定DN 修改CN名称
    # ldapObj.update_cn(data[0].entry_dn,new_cn="李南男")
    # --------------------------------
    # 获取objectClass 详细信息
    # ldapObj.get_object_classes_info("organizationalUnit")
    # ldapObj.get_object_classes_info("posixAccount")
    # ldapObj.get_object_classes_info("inetOrgPerson")
    # ldapObj.get_object_classes_info("person")
    # 没有邮箱地址的用户:

    s = ldapObj.get_userdn_by_args(ou="Product")
    data = ldapObj.get_userdn_by_args(base_dn=s[0].entry_dn, objectclass="inetOrgPerson")
    for i in data:
        print(i.entry_dn)
    print(s)

```
