# AGENTS.md

本仓库是 Get Oudio 使用的 wrapper-lite fork，上游来源为 `WorldObservationLog/wrapper`。同步上游前确认当前工作树、来源修订及代码差异，并核对相邻 `get-oudio` 的 `AppleMusicQEMUProcess`、`AppleMusicRuntimeManager` 和 downloader 的 `internal/wrapper`。Get Oudio 使用受控 QEMU 包；旧 Docker/四端口路径和上游通用启动方式不能直接代替该集成。保留无关未提交改动及用户的运行时数据。

## 协议与凭据

wrapper-lite 经单一 HTTP 服务提供 `/status`、`/m3u8`、`/key`、`/webplayback`、`/license` 等接口，响应采用 `{code,msg,data}`。HTTP 200 不代表业务成功；Get Oudio 还须核对所记录 QEMU 进程身份，并在 `/status` 的 `code=0` 且 `regions` 非空时才将服务视为已登录。变更路由、字段、错误或登录生命周期时同步核对 downloader 和 Get Oudio 的就绪判断，主机端转发须保持 loopback 绑定。

QEMU 登录使用 `--login-stdin`，账号、密码及后续验证码从标准输入传入；launcher 必须拒绝含凭据的 `--login` 参数。`wrapper-lite-qemu.cpp`、`qemu/init` 和 guest 参数传递需一同检查：fw_cfg 只承载非敏感参数，guest 临时参数位于 `/run`，不得把账号、密码、验证码或 token 写入命令行、kernel 参数、参数文件、日志或发布包。用户的持久 `data.img` 与版本化程序包分开管理；更新程序不得覆盖或清理认证数据。不得在诊断中输出 token 前缀、密钥或原始登录串口内容。

## 制品与验证

macOS arm64 QEMU 包须包含 launcher、guest 资产、QEMU 可执行文件及其非系统动态库和模块；`.github/scripts/bundle-macos-qemu.sh` 与构建工作流是打包入口。修改构建、启动或依赖时检查可执行权限、Mach-O 架构、`otool -L` 的依赖闭包、嵌套签名，以及在无构建机 Homebrew 依赖的 macOS 环境启动并请求 `/status`。发布制品须固定来源提交和 SHA-256；空 `regions` 的启动检查只证明服务可启动，登录、实际 2FA、缓存重启和受影响格式的真实下载要在 Get Oudio 签名安装链路分别验收，未发生的挑战明确记为未验收。纯文档改动运行 `git diff --check`。
