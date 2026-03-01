<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo_X.png">
</div>



<div align="center">
    <h1>PiliPlusX</h1>
<div align="center">
    

</div>
    <p>使用Flutter开发的BiliBili第三方客户端</p>
    
<img src="assets/screenshots/510shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="home" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="home" />
<br/>
</div>


<br/>

## 空降指挥部

- PiliPlus [特色功能](#功能)
- PiliPlusX 独家功能见 [TODO List](https://github.com/cnctem/PiliPlusX/blob/dev/docs/TODO.md) 完成项
- [下载最新版本](https://github.com/cnctem/PiliPlusX/releases/latest)
- [快捷键功能说明](docs/快捷键说明.md)
- [安卓字体修复说明](#PiliPlusX字体修复说明)
- [鸿蒙版详情](https://github.com/cnctem/PiliPlusX/tree/ohos#当前分支ohos说明)
- [港澳台代理](#港澳台代理)
- [致谢](#致谢)
- [请提出你的宝贵建议!](https://github.com/cnctem/PiliPlusX/issues)

## 适配平台

- [x] Android
- [x] iOS
- [x] HarmonyOS [(分支说明)](https://github.com/cnctem/PiliPlusX/tree/ohos#当前分支ohos说明)
- [x] Pad & Fold
- [x] macOS
- [x] Windows
- [x] Linux (需自行编译体验, [详情](https://github.com/cnctem/PiliPlusX/issues/7#issuecomment-3650079829))

## refactor

- [ ] gRPC [wip]
- [x] 用户界面
- [x] 其他

## feat

- [x] 编辑动态
- [x] DLNA 投屏
- [x] 离线缓存/播放
- [x] 移动端支持点击弹幕悬停，点赞、复制、举报 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 播放音频
- [x] 跳过番剧片头/片尾
- [x] 安卓端 `loudnorm` 适配 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] Win/Mac 支持极验、短信登录 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 视频截取动图 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] AI 原声翻译
- [x] SuperChat
- [x] 播放课堂视频
- [x] 发起投票
- [x] 发布动态/评论支持`富文本编辑`/`表情显示`/`@用户`
- [x] 修改消息设置
- [x] 修改聊天设置
- [x] 展示折叠消息
- [x] 查看用户图文
- [x] 动态话题
- [x] 直播分区
- [x] 分享`视频`/`番剧`/`动态`/`专栏`/`直播`至消息
- [x] 创建/修改/删除关注分组
- [x] 移除粉丝
- [x] 直播弹幕发送表情
- [x] 收藏夹排序
- [x] 稍后再看 ~~`未看`~~ / `未看完` / ~~`已看完`~~ 分类
- [x] WebDAV 备份/恢复设置
- [x] 保存评论/动态
- [x] 高级弹幕 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 取消/置顶评论
- [x] 记笔记
- [x] 多账号支持 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 屏蔽带货动态/评论
- [x] 互动视频
- [x] 发评/动态反诈
- [x] 高能进度条
- [x] 滑动跳转预览视频缩略图
- [x] Live Photo
- [x] 复制/移动/排序收藏夹/稍后再看视频
- [x] 超分辨率
- [x] 合并弹幕
- [x] 会员彩色弹幕
- [x] 播放全部/继续播放/倒序播放
- [x] Cookie登录
- [x] 显示视频分段信息
- [x] 调节字幕大小
- [x] 调节全屏弹幕大小
- [x] 收藏夹/稍后再看多选删除
- [x] 搜索用户动态
- [x] 直播弹幕
- [x] 修改头像/用户名/签名/性别/生日
- [x] 创建/编辑/删除收藏夹
- [x] 评论楼中楼查看对话
- [x] 评论楼中楼定位点击查看的评论
- [x] 评论楼中楼按热度/时间排序
- [x] 评论点踩
- [x] 私信发图
- [x] 投币动画
- [x] 取消/追番，更新追番状态
- [x] 取消/订阅合集
- [x] SponsorBlock
- [x] 显示视频完整合集
- [x] 三连动画
- [x] 番剧三连
- [x] 带图评论
- [x] 视频TAG
- [x] 筛选搜索
- [x] 转发动态
- [x] 合集图片
- [x] 删除/置顶/撤回私信
- [x] 举报用户/评论/视频/动态
- [x] 删除/发布/置顶文本/图片动态
- [x] 其他

## opt

- [x] 专栏界面
- [x] 私信界面
- [x] 收藏面板
- [x] PIP
- [x] 视频封面
- [x] 回复界面
- [x] 系统通知
- [x] 评论显示
- [x] 亮度调节
- [x] 视频播放
- [x] 视频staff
- [x] 防止bottomsheet遮挡全屏视频
- [x] 回车绑定发送
- [x] 选择鸿蒙黑体/系统字体
- [x] 其他

## fix

- [x] 番剧分集点赞/投币/收藏
- [x] 字体回调（Flutter 3.38 导致）
- [x] bugs

<br/>

## 功能

- [x] 推荐视频列表(app端)
- [x] 最热视频列表
- [x] 热门直播
- [x] 番剧列表
- [x] 屏蔽黑名单内用户视频
- [x] 无痕模式（播放视为未登录）
- [x] 游客模式（推荐视为未登录）

- [x] 用户相关
  - [x] 粉丝、关注用户、拉黑用户查看
  - [x] 用户主页查看
  - [x] 关注/取关用户
  - [x] 离线缓存
  - [x] 稍后再看
  - [x] 观看记录
  - [x] 我的收藏
  - [x] 站内私信
  
- [x] 动态相关
  - [x] 全部、投稿、番剧分类查看
  - [x] 动态评论查看
  - [x] 动态评论回复功能

- [x] 视频播放相关
  - [x] 双击快进/快退
  - [x] 双击播放/暂停
  - [x] 垂直方向调节亮度/音量
  - [x] 垂直方向上滑全屏、下滑退出全屏
  - [x] 水平方向手势快进/快退
  - [x] 全屏方向设置
  - [x] 倍速选择/长按2倍速
  - [x] 硬件加速（视机型而定）
  - [x] 画质选择（高清画质未解锁）
  - [x] 音质选择（视视频而定）
  - [x] 解码格式选择（视视频而定）
  - [x] 弹幕
  - [x] 字幕
  - [x] 记忆播放
  - [x] 视频比例: 高度/宽度适应、填充、包含等
     
- [x] 搜索相关
  - [x] 热搜
  - [x] 搜索历史
  - [x] 默认搜索词
  - [x] 投稿、番剧、直播间、用户搜索
  - [x] 视频搜索排序、按时长筛选
    
- [x] 视频详情页相关
  - [x] 视频选集(分p)切换
  - [x] 点赞、投币、收藏/取消收藏
  - [x] 相关视频查看
  - [x] 评论用户身份标识
  - [x] 评论(排序)查看、二楼评论查看
  - [x] 主楼、二楼评论回复功能
  - [x] 评论点赞
  - [x] 评论笔记图片查看、保存

- [x] 设置相关
  - [x] 画质、音质、解码方式预设      
  - [x] 图片质量设定
  - [x] 主题模式: 亮色/暗色/跟随系统
  - [x] 震动反馈(可选)
  - [x] 高帧率
  - [x] 自动全屏
  - [x] 横屏适配
- [ ] 等等

<br/>

## 下载

可以通过右侧release进行下载或拉取代码到本地进行编译

<br/>

## 港澳台代理

由于PiliPlus使用了web接口,所以不能直接使用哔哩漫游的公共服务器

搭建方法: 直接反向代理api.bilibili.com或添加下面几个路由的支持:
```text
/x/web-interface/view
/x/web-interface/wbi/search/type
/x/player/wbi/playurl
/pgc/season/index/result
/pgc/web/timeline
/pgc/season/index/condition
/pgc/player/web/v2/playurl
/pgc/view/web/season
```

可用的公共服务器:

注意:由于请求代理服务器会携带cookie，所以请使用可信任的代理服务器或不登录账号进行使用

|提供者|服务器|捐赠|
|------|------|:----:|
|gucooing|https://blblapi.alsl.xyz||

感谢 [gucooing](https://github.com/gucooing) !

## PiliPlusX版本说明

- 主线版本: 基于上游[`main`分支](https://github.com/bggRGjQaUbCoE/PiliPlus/tree/main)更新最及时，打包 Android、iOS、Windows、macOS 版本
- pink版本: 主线版本修改包名共存，详见 [#21](https://github.com/cnctem/PiliPlusX/issues/21)
- oddo版本: 基于上游[`flutter_3.35.7`分支](https://github.com/bggRGjQaUbCoE/PiliPlus/tree/flutter_3.35.7)，面向color OS等字体错误的定制安卓，仅打包 Android 版本
- ohos版本: 基于上游[qinshah/PiliPlus](https://github.com/qinshah/PiliPlus)

## PiliPlusX字体修复说明

- 字体问题由`flutter3.38.x`要求显式定义字体，而color OS及个别定制安卓的字体机制采用映射到系统Roboto的方案，导致flutter找不到定义的字体从而产生字体问题，表现为显示为一种错误的衬线字体
- 主线版本 在关闭设置项“使用系统字体”后将字体指定为使用鸿蒙黑体，基本解决问题
- 如果你是ColorOS等字体错误的定制安卓，且希望显示手机自定义主题字体，推荐使用oddo版本，通过使用`flutter3.35.7`彻底解决字体问题。下载最新oddo版 [v1.1.1.6-oddo](https://github.com/cnctem/PiliPlusX/releases/tag/v1.1.1.6)
- 由于ColorOS在逐步推送修复完Flutter字体回退问题的OTA更新，oddo分支将不再维护，主线版本内嵌字体也将在后续版本改为支持用户导入字体


## 声明

此项目（PiliPlusX）是个人学习 Flutter 而开发，仅用于交流学习 Flutter 技术，请于下载后24小时内删除，严禁在互联网上传播软件安装包！

上游项目声明
>此项目（PiliPlus）是个人为了兴趣而开发，仅用于学习和测试，请于下载后24小时内删除。
所用API皆从官方网站收集, 不提供任何破解内容。

**感谢使用**

## 致谢

- 在此致敬原作者: [guozhigq/pilipala](https://github.com/guozhigq/pilipala)
- 在此致敬上游作者: [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
- 在此致敬上游作者: [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- 在此致敬上游作者: [gucooing/PiliPlus](https://github.com/gucooing/PiliPlus)
- 在此致敬上游作者: [chenx-dust/PiliPlus](https://github.com/chenx-dust/PiliPlus)
- 致谢鸿蒙版上游 [qinshah/PiliPlus](https://github.com/qinshah/PiliPlus)
- 鸿蒙适配[致谢](https://github.com/cnctem/PiliPlusX/tree/ohos?tab=readme-ov-file#感谢)

- bilibili-API-collect
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- 等等