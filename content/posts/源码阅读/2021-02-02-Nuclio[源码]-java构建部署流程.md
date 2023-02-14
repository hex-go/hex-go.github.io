---
title: 'Nuclio[源码]-java构建部署流程'
categories:
  - 源码阅读
tags:
  - Source Code
  - Nuclio
  - 待完善
date: '2021-02-02 02:49:36'
top: false
comments: true
---

# 重要

阅读nuclio源码，分析nuclio平台中java由源码到服务启动的全过程。

# 环境说明

nuclio: 1.4.17
kubernetes: 1.15.3

# 源码： 构建过程

有`nuctl`的build command往下查看调用

1. `pkg/nuctl/command/build.go`文件下，`newBuildCommandeer`函数内部调用了`rootCommandeer.platform.CreateFunctionBuild`

   > 走platform接口`pkg/platform/platform.go`，因为platform类型为`kube`，所以调用`pkg/platform/kube/platform.go`。
   >
   > 其中kube的NewPlatform继承了`pkg/platform/abstract/platform.go`的实例，`CreateFunctionBuild`就在`abstract/`中具体定义的。

2. `pkg/platform/abstract/platform.go`文件下，`CreateFunctionBuild`函数内部，实例化了一个builder，并执行`builder.Build`函数。

3. `pkg/processor/build/builder.go`文件下：

   `Build`                                                            函数调用`buildProcessorImage`函数

   `buildProcessorImage`                               函数调用`createProcessorDockerfile`函数

   `createProcessorDockerfile`                   函数调用`getRuntimeProcessorDockerfileInfo`函数

   `getRuntimeProcessorDockerfileInfo`   函数调用`resolveProcessorDockerfileInfo`函数

   - `resolveProcessorDockerfileInfo`         函数调用`runtime.GetProcessorDockerfileInfo`函数

     > 走runtime接口`pkg/processor/build/runtime/runtime.go`，
     >
     > 因为runtime类型为`java`，所以调用`pkg/processor/build/runtime/java/runtime.go`。

     - `pkg/processor/build/runtime/java/runtime.go`中，有具体的`GetProcessorDockerfileInfo`定义（包含onbuild信息）。

   - `resolveProcessorDockerfileInfo`         函数调用`GenerateDockerfileContents`函数

     - `GenerateDockerfileContents`                  函数调用`platform.GetOnbuildStages`函数

       > platform接口`pkg/platform/platform.go`，`GetOnbuildStages` 具体定义在 `pkg/platform/abstract/platform.go`。
       >

       - `pkg/platform/abstract/platform.go`文件下：

         `GetOnbuildStages`                                         函数内部调用`ContainerBuilder.GetOnbuildStages`函数。

         > BuilderPusher接口`pkg/containerimagebuilderpusher/containerimagebuilder.go`，
         >
         > 因为kind为`kaniko`，所以调用`pkg/containerimagebuilderpusher/kaniko.go`

       - `pkg/containerimagebuilderpusher/kaniko.go`文件下：

         GetOnbuildStages函数主要做以下操作

         将`onbuildArtifacts`转换为`"FROM %s(artifact.Image) AS %s(artifact.Name)" \n ARG NUCLIO_LABEL \n ARG NUCLIO_ARCH`

     - `GenerateDockerfileContents`                  函数调用`platform.TransformOnbuildArtifactPaths`函数

       > platform接口`pkg/platform/platform.go`，`GetOnbuildStages` 具体定义在 `pkg/platform/abstract/platform.go`。

       - `TransformOnbuildArtifactPaths`             函数内部调用`ContainerBuilder.GetOnbuildStages`函数。

         > BuilderPusher接口`pkg/containerimagebuilderpusher/containerimagebuilder.go`，
         >
         > `TransformOnbuildArtifactPaths`         具体定义在   `pkg/containerimagebuilderpusher/kaniko.go`

       - `pkg/containerimagebuilderpusher/kaniko.go`文件下：

         `TransformOnbuildArtifactPaths` 函数主要做以下操作

         将`onbuildArtifacts`转换为`--from=%s(artifact.Name)  %s(artifat.Path[x])   `





从后向前推，构建function函数最终镜像的Dockerfile在`pkg/processor/build/builder.go`, 函数`GenerateDockerfileContents`。

内容如下：

```go
// GenerateDockerfileContents return function docker file
func (b *Builder) GenerateDockerfileContents(baseImage string,
	onbuildArtifacts []runtime.Artifact,
	imageArtifactPaths map[string]string,
	directives map[string][]functionconfig.Directive,
	healthCheckRequired bool) (string, error) {

	// now that all artifacts are in the artifacts directory, we can craft a Dockerfile
	dockerfileTemplateContents := `# Multistage builds

{{ range $onbuildStage := .OnbuildStages }}
{{ $onbuildStage }}
{{ end }}

# From the base image
FROM {{ .BaseImage }}

# Old(er) Docker support - must use all build args
ARG NUCLIO_LABEL
ARG NUCLIO_ARCH
ARG NUCLIO_BUILD_LOCAL_HANDLER_DIR

{{ if .PreCopyDirectives }}
# Run the pre-copy directives
{{ range $directive := .PreCopyDirectives }}
{{ $directive.Kind }} {{ $directive.Value }}
{{ end }}
{{ end }}

# Copy required objects from the suppliers
{{ range $localArtifactPath, $imageArtifactPath := .OnbuildArtifactPaths }}
COPY {{ $localArtifactPath }} {{ $imageArtifactPath }}
{{ end }}

{{ range $localArtifactPath, $imageArtifactPath := .ImageArtifactPaths }}
COPY {{ $localArtifactPath }} {{ $imageArtifactPath }}
{{ end }}

{{ if .HealthcheckRequired }}
# Readiness probe
HEALTHCHECK --interval=1s --timeout=3s CMD /usr/local/bin/uhttpc --url http://127.0.0.1:8082/ready || exit 1
{{ end }}

# Run the post-copy directives
{{ range $directive := .PostCopyDirectives }}
{{ $directive.Kind }} {{ $directive.Value }}
{{ end }}

# Run processor with configuration and platform configuration
CMD [ "processor" ]
`

	onbuildStages, err := b.platform.GetOnbuildStages(onbuildArtifacts)
	if err != nil {
		return "", errors.Wrap(err, "Failed to transform retrieve onbuild stages")
	}

	// Transform `onbuildArtifactPaths` depending on the builder being used
	onbuildArtifactPaths, err := b.platform.TransformOnbuildArtifactPaths(onbuildArtifacts)
	if err != nil {
		return "", errors.Wrap(err, "Failed to transform onbuildArtifactPaths")
	}

	dockerfileTemplate, err := template.New("singleStageDockerfile").
		Parse(dockerfileTemplateContents)
	if err != nil {
		return "", errors.Wrap(err, "Failed to create onbuildImage template")
	}

	var dockerfileTemplateBuffer bytes.Buffer
	err = dockerfileTemplate.Execute(&dockerfileTemplateBuffer, &map[string]interface{}{
		"BaseImage":            baseImage,
		"OnbuildStages":        onbuildStages,
		"OnbuildArtifactPaths": onbuildArtifactPaths,
		"ImageArtifactPaths":   imageArtifactPaths,
		"PreCopyDirectives":    directives["preCopy"],
		"PostCopyDirectives":   directives["postCopy"],
		"HealthcheckRequired":  healthCheckRequired,
	})

	if err != nil {
		return "", errors.Wrap(err, "Failed to run template")
	}

	dockerfileContents := dockerfileTemplateBuffer.String()

	return dockerfileContents, nil
}

```
`b.platform.GetOnbuildStages(onbuildArtifacts)`调用了platform接口下的功能。



platform说明如下: 

- `pkg\platform\platform.go`中定义接口
- `pkg\platform\types.go`中定义数据结构
- `pkg\platform\factory\factory.go`为工厂函数，根据platform参数
  1. `local`： 调用`pkg\platform\local\platform.go`中的`NewPlatform`创建platform 实例
  2. `kube`： 调用`pkg\platform\kube\platform.go`中的`NewPlatform`创建platform 实例
- `pkg\platform\abstract\platform.go`为具体创建platform实例的。被`local`和`kube`下的`NewPlatform`调用。

```bash
pkg/platform
├── abstract
│   ├── platform.go
├── config
│   └── types.go
├── errors.go
├── factory
│   └── factory.go
├── kube
│   ├── platform.go
│   ├── types.go
├── local
│   ├── platform.go
│   └── types.go
├── platform.go
└── types.go
```



根据上面说明，函数执行了`kube/`下的`platform.go`，之后调用`abstract/platform.go`下的







函数`GetProcessorDockerfileInfo`, `pkg/processor/build/runtime/`目录下，`java/runtime.go`

```go
func (j *java) GetProcessorDockerfileInfo(onbuildImageRegistry string) (*runtime.ProcessorDockerfileInfo, error) {

	processorDockerfileInfo := runtime.ProcessorDockerfileInfo{}
	processorDockerfileInfo.BaseImage = "openjdk:9-jre-slim"

	// fill onbuild artifact
	artifact := runtime.Artifact{
		Name: "java-onbuild",
		Image: fmt.Sprintf("%s/nuclio/handler-builder-java-onbuild:%s-%s",
			onbuildImageRegistry,
			j.VersionInfo.Label,
			j.VersionInfo.Arch),
		Paths: map[string]string{
			"/home/gradle/bin/processor":                                  "/usr/local/bin/processor",
			"/home/gradle/src/wrapper/build/libs/nuclio-java-wrapper.jar": "/opt/nuclio/nuclio-java-wrapper.jar",
		},
	}
	processorDockerfileInfo.OnbuildArtifacts = []runtime.Artifact{artifact}

	return &processorDockerfileInfo, nil
}
```



调用关系

- `createProcessorDockerfile`: 
  1. 调用 `getRuntimeProcessorDockerfileInfo`函数，生成`content`和`DockerfilePath`
-  `getRuntimeProcessorDockerfileInfo`函数: 
  1. 调用`resolveProcessorDockerfileInfo`函数收集processor的dockerfile信息
  2. 获取用户输入的指令`FunctionConfig.Spec.Build.Directives`，如果设置了command参数，则获取`FunctionConfig.Spec.Build.Commands`转换为指令并与构建过程的合并。
  3. 调用`GenerateDockerfileContents`函数，将第一步获取的内容转换为`DockerfileContent`。
- `resolveProcessorDockerfileInfo`函数：
  1. 调用`GetProcessorDockerfileInfo`函数，获取默认的runtime。
  2. 调用`getProcessorDockerfileBaseImage`函数，a. 第一优先级FunctionConfig.Spec.Build.BaseImage；b. GetProcessorDockerfileInfo函数中格式为fmt.Sprintf("%s/nuclio/handler-builder-java-onbuild:%s-%s"。
  3. 调用函数`renderDependantImageURL`
  4. 调用函数`getProcessorDockerfileOnbuildImage`
  5. 增加health-check组件
- `GetProcessorDockerfileInfo`函数(meige)：
  1. 指定BaseImage和OnbuildArtifacts，其中OnbuildArtifacts包含onbuildImage和path。

 `GetProcessorDockerfileInfo` -> `resolveProcessorDockerfileInfo` -> `getRuntimeProcessorDockerfileInfo` -> `createProcessorDockerfile`



# 源码： 部署过程


# Reference

[nuclio github](https://github.com/nuclio/nuclio)