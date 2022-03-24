---
title: Gorm-使用gormigrate
categories:
  - Golang
tags:
  - Go
  - Draft
date: '2020-05-28 11:11:41'
top: false
comments: true
---

# 重要

# 环境说明

基于的gomigrate版本为`v1.6.0`注意与v2版本不兼容.

# 使用

## 1. main函数中调用migrate

main函数

```go
package main

import (
	"test/cmd"
)

func main() {
	cmd.Execute()
}

```

cmd包内的Execute函数

```go
package cmd

import (
	"github.com/spf13/cobra"
	"test/cmd/api"
	"os"
)

var rootCmd = &cobra.Command{
	Use:               "heroku",
	Short:             "heroku API server",
	SilenceUsage:      true,
	DisableAutoGenTag: true,
	Long:              `Start heroku API server`,
	PersistentPreRunE: func(*cobra.Command, []string) error { return nil },
}

func init() {
    // Add api start cmd
	rootCmd.AddCommand(api.StartCmd)
}

//Execute : run commands
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(-1)
	}
}

```

api包的start cmd 配置

```go

package api

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/rs/zerolog"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"test/cmd/migrate"
	"io/ioutil"
	"os"
	"strconv"
	"strings"
)

var (
	config   string
	port     string
	loglevel uint8
	cors     bool
	cluster  bool
	//StartCmd : set up restful api server
	StartCmd = &cobra.Command{
		Use:     "server",
		Short:   "Start test API server",
		Example: "test server -p 8083",
		PreRun: func(cmd *cobra.Command, args []string) {
            // 服务初始化配置
			setup()
		},
		RunE: func(cmd *cobra.Command, args []string) error {
            // 服务启动
			return run()
		},
	}
)

func init() {
	StartCmd.PersistentFlags().StringVarP(&port, "port", "p", "8083", "Tcp port server listening on")
}

func setup() {
	//1. database migrate
	err = migrate.New()
	if err != nil {
		log.Fatal(fmt.Sprintf("Migrate sql error: %s", err.Error()))
	}

}

func run() error {
	engine := gin.Default()
	binding.Validator = new(validate.DefaultValidator)

	router.SetUp(engine, cors)
	return engine.Run(":" + port)
}

```



## 2. 执行数据库初始化的migrate入口函数

```go
// Initialize & migrate departments & users & maybe other stuffs
package migrate

import (
	"github.com/jinzhu/gorm"
	"gopkg.in/gormigrate.v1"
	"icosdeploy/pkg/api/dao"
	"icosdeploy/pkg/api/model"
)

func New() error {
	db := dao.GetDb()
	m := gormigrate.New(db, gormigrate.DefaultOptions, []*gormigrate.Migration{})
	// 1. 数据库表的初始化
	m.InitSchema(func(tx *gorm.DB) error {
		err := tx.AutoMigrate(
			&model.App{},
			&model.Log{},
			&model.Rule{},
		).Error
		if err != nil {
			return err
		}
		return nil
	})
	_ = m.Migrate()
	
    // 每次不同的migrate
	m = gormigrate.New(db, gormigrate.DefaultOptions, []*gormigrate.Migration{
		// 插入初始化数据
        SeedData,
        // 创建表
		AddTable,
        // 表增加列
		AddColumn,
        // 在此处以下逐次追加 migrate
	})
	return m.Migrate()

}

```



## 3. 迁移示例

### 3.1 插入初始化数据`SeedSizes`

```go
package migrate

import (
	"github.com/jinzhu/gorm"
	"gopkg.in/gormigrate.v1"
	"icosdeploy/pkg/api/model"
)

var (
	SizeSmall = &model.QletSize{Name: "small", Cpu: "1", Memory: "2", Status: "1"}
	SizeLarge = &model.QletSize{Name: "large", Cpu: "2", Memory: "4", Status: "1"}
)

// Sizes insert
var SeedData = &gormigrate.Migration{
	ID: "SEED_DATA",
	Migrate: func(db *gorm.DB) error {
		err := db.Create(&SizeSmall).Error
		if err != nil {
			return err
		}
		err = db.Create(&SizeLarge).Error
		if err != nil {
			return err
		}
		return err
	},
	Rollback: func(db *gorm.DB) error {
		err := db.Delete(&SizeSmall).Error
		if err != nil {
			return err
		}
		err = db.Delete(&SizeLarge).Error
		if err != nil {
			return err
		}
		return err
	},
}
```



### 3.2 创建表

```go
package migrate

import (
	"github.com/jinzhu/gorm"
	"gopkg.in/gormigrate.v1"
	"icosdeploy/pkg/api/model"
)

// AddTable create
var AddTable = &gormigrate.Migration{
	ID: "Add_TABLE",
	Migrate: func(db *gorm.DB) error {
		//if db.HasTable(&model.Job{}){
		//
		//}
		err := db.CreateTable(&model.Job{}).Error
		if err != nil {
			return err
		}
		return err
	},
	Rollback: func(db *gorm.DB) error {
		err := db.DropTableIfExists(&model.Job{}).Error
		if err != nil {
			return err
		}
		return err
	},
}

```



### 3.3 表添加字段

```go
package migrate

import (
	"github.com/jinzhu/gorm"
	"gopkg.in/gormigrate.v1"
	"icosdeploy/pkg/api/model"
)

// create column
var AddColumn = &gormigrate.Migration{
	ID: "ADD_COLUMN",
	Migrate: func(db *gorm.DB) error {
		// when table already exists, it just adds fields as columns
		return db.AutoMigrate(&model.Algo{}).Error
	},
	Rollback: func(db *gorm.DB) error {
		return db.Model(&model.Algo{}).DropColumn("sub_path").Error
	},
}

```



### 3.4 添加一个路由

+ 创建此路由存储数据的表
+ 在casbin中增加此路由相关`rule`
+ 修改role, 以后增加的用户,自动在Casbin中增加规则

创建表,参考`3.2创建表`

修改casbin-rule和修改role

+ casbin 中剔除用户(v3='')和系统管理员(v0='adminRole'),剩余的为角色+路由+方法+租户的数据,再根据: `角色`+`租户`分组,添加规则数据,  插入新数据, 其他信息保持不变, 路由为新插入路由.
+ role 在每个role数据中增加`{"object":"/api/v1/jobs","action":"*"}`, 路由为新插入路由, 方法admin为*,其他为`GET`.
+ 注意角色的回滚,要将数据update为上一次修改role的数据.

```
package migrate

import (
	"fmt"
	"github.com/jinzhu/gorm"
	"gopkg.in/gormigrate.v1"
	"icosdeploy/pkg/api/log"
	"icosdeploy/pkg/api/model"
)

var (
	roleAddJobs1 = &model.Role{Name: "admin", Policy: model.JSON(`[{"object":"/api/v1/jobs","action":"*"},{"object":"/api/v1/pvcs","action":"*"},{"object":"/api/v1/qlet/start","action":"*"},{"object":"/api/v1/qlet/stop","action":"*"},{"object":"/api/v1/application","action":"*"},{"object":"/api/v1/qlet","action":"*"},{"object":"/api/v1/qletSize","action":"GET"},{"object":"/api/v1/results","action":"*"},{"object":"/api/v1/dbaas","action":"*"},{"object":"/api/v1/registry","action":"*"},{"object":"/api/v1/scan","action":"*"},{"object":"/api/v1/chart","action":"*"}]`)}
	roleAddJobs2 = &model.Role{Name: "observer", Policy: model.JSON(`[{"object":"/api/v1/jobs","action":"GET"},{"object":"/api/v1/pvcs","action":"GET"},{"object":"/api/v1/application","action":"GET"},{"object":"/api/v1/qlet","action":"GET"},{"object":"/api/v1/qletSize","action":"GET"},{"object":"/api/v1/results","action":"GET"},{"object":"/api/v1/dbaas","action":"GET"},{"object":"/api/v1/registry","action":"GET"},{"object":"/api/v1/scan","action":"GET"},{"object":"/api/v1/chart","action":"GET"}]`)}
	roleAddJobs3 = &model.Role{Name: "ops", Policy: model.JSON(`[{"object":"/api/v1/jobs","action":"GET"},{"object":"/api/v1/pvcs","action":"GET"},{"object":"/api/v1/qlet/start","action":"*"},{"object":"/api/v1/qlet/stop","action":"*"},{"object":"/api/v1/application","action":"GET"},{"object":"/api/v1/qlet","action":"GET"},{"object":"/api/v1/qletSize","action":"GET"},{"object":"/api/v1/results","action":"GET"},{"object":"/api/v1/dbaas","action":"GET"},{"object":"/api/v1/registry","action":"GET"},{"object":"/api/v1/scan","action":"GET"},{"object":"/api/v1/chart","action":"GET"}]`)}
)

// PermJobs create
var PermJobs = &gormigrate.Migration{
	ID: "Perm_JOBS",
	Migrate: func(db *gorm.DB) (err error) {
		err = db.Model(&model.Role{}).Where("name = ?", "admin").Update("Policy", roleAddJobs1.Policy).Error
		if err != nil {
			return err
		}
		err = db.Model(&model.Role{}).Where("name = ?", "observer").Update("Policy", roleAddJobs2.Policy).Error
		if err != nil {
			return err
		}
		err = db.Model(&model.Role{}).Where("name = ?", "ops").Update("Policy", roleAddJobs3.Policy).Error
		if err != nil {
			return err
		}
		
		
		var rules []model.CasbinRule
		// v0=角色\用户 v1=路由 v2=租户 v3=方法()
		// group by v2 and v0 && v3 != ''  raw-sql
		//db.Where("id = ?", id).Group().Find(&rules)
		db.Raw("SELECT * FROM casbin_rule where v3 <> '' and v0 <> 'adminRole' GROUP BY v2, v0").Scan(&rules)
		for _, r := range rules {
			newRule := &model.CasbinRule{
				PType: r.PType,
				V0:    r.V0,
				V1:    "/api/v1/jobs",
				V2:    r.V2,
				V3:    r.V3,
				V4:    r.V4,
				V5:    r.V5,
			}
			log.Debug(fmt.Sprintf("%#v", newRule))
			db.Create(newRule)
		}
		return err
	},
	Rollback: func(db *gorm.DB) error {
		err := db.DropTableIfExists(&model.Job{}).Error
		if err != nil {
			return err
		}
		err = db.Model(&model.Role{}).Where("name = ?", "admin").Update("Policy", role1.Policy).Error
		if err != nil {
			return err
		}
		err = db.Model(&model.Role{}).Where("name = ?", "observer").Update("Policy", role2.Policy).Error
		if err != nil {
			return err
		}
		err = db.Model(&model.Role{}).Where("name = ?", "ops").Update("Policy", role3.Policy).Error
		if err != nil {
			return err
		}
		err = db.Exec("DELETE FROM casbin_rule WHERE v1 = '/api/v1/jobs'").Error
		err = db.Delete(&role3).Where("v1 = ?", "/api/v1/jobs").Error
		if err != nil {
			return err
		}

		return err
	},
}

```





# Reference

[Gorm Gotchas--gorm+migrate+uuid](https://blog.depado.eu/post/gorm-gotchas)

[gorm--gormigrate--uuid](https://ithelp.ithome.com.tw/articles/10213461)