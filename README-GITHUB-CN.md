# 用 iPhone 通过 GitHub Actions 编译（中文说明）

> 这是一个尚未在真实 iOS 17 + Dopamine 设备上验证的独立插件原型。云端编译成功不等于设备运行稳定。请先备份并准备好进入安全模式/移除 tweak 的恢复方法。

## 通过 iPhone 操作

1. 在 Safari 登录 GitHub，创建一个新的 **Private** repository（私有仓库），例如 `HeliumDopamine`。
2. 在 GitHub 仓库页面选择 **Add file → Upload files**。
3. 解压本项目 ZIP，把其中的文件和文件夹上传到仓库根目录。务必保留 `.github/workflows/build.yml`；如果网页隐藏了以点开头的目录，需确认该目录确实已上传。
4. 点击 **Commit changes** 保存。
5. 打开仓库的 **Actions** 标签页，选择 **Build rootless tweak**，点击 **Run workflow**。
6. 等待运行结束。若失败，打开失败步骤并查看日志；不要把包含账号令牌或隐私的日志公开分享。
7. 若成功，在该次运行页面底部的 **Artifacts** 下载 `HeliumDopamine-deb`，解压后取得 `.deb`。

## 注意

- 目前工程是原型：天气、歌词、完整设置面板、可靠的截屏前隐藏等功能尚未实现。
- 构建失败时，需要根据 Actions 日志修复源码或 SDK/工具链问题；工作流不保证一次成功。
- 仅在自己拥有并有权管理的设备上安装。安装前保留移除包/进入安全模式的办法。
- 这是独立重写原型，不包含原 IPA 的私有二进制或私有代码。
