<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png">
</div>



<div align="center">
    <h1>PiliNara</h1>
<div align="center">
    
</div>
    <p>基于PiliPlus做了一些自用修改</p>
    
<img src="assets/screenshots/510shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="home" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="home" />
<br/>
</div>


<br/>

## 项目说明
- 本项目PiliNara是基于[PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)进行修改的,做了一些自用的改动.
- 本仓库保留了PiliPlus的所有功能,并在此基础上进行了部分自用的优化和调整.支持导入PiliPlus的设置和数据，也应该支持了导出设置和数据到PiliPlus.
- 本项目会定期同步PiliPlus的更新,并在此基础上进行修改和优化.
- 本项目仅供个人学习和测试使用，目前只打包了安卓版本,如有需要请自行Fork后编译.
- 有啥需要的功能或者想法欢迎提issue或者PR,我会尽量抽时间进行开发和完善.
- 本人开发水平有限，可能存在一些bug和不完善的地方，欢迎提交issue和PR.

在此致敬原作者和上游作者的无私奉献。如有侵权请联系删除。

## 改动说明(未来计划？)

Fork特性：

**基础适配与界面**
- [x] 应用名称由PiliPlus更改为PiliNara，做了各平台相应替换以实现共存
- [x] 修复Flutter在澎湃小窗下无法正常显示的问题，参考Flutter官方issue [#161086](https://github.com/flutter/flutter/issues/161086)，该问题似乎在HyperOS3上被修复
   修复方案参考了[venera/pull/467](https://github.com/venera-app/venera/pull/467)
- [x] 支持自定义「我的」页面卡片顺序和显示数量
- [x] 「我的」页面新增历史记录卡片预览和「稍后再看」卡片板块
- [x] 支持自动侧边栏切换，并可配置触发宽度
- [x] Android 支持预测性返回动画
- [x] 图片长按/右键菜单支持复制图片
- [x] 大量界面升级了 MD3E 风格，界面好看了点？

**字体系统**（基于上游初始版本修改）
- [x] **自定义字体系统重构**：导入池支持多套字体同时管理，按内容哈希自动去重，重复导入同一文件不再占用空间；字体名读取字体文件内部名称（支持中文名/字重区分），非字体文件自动回落文件名
- [x] **弹幕字体并入统一字体池**：弹幕字体与应用字体共用一套导入池，不再维护独立目录；移除正在使用的字体时立即回落，不会留下指向已删字体的设置
- [x] 字体设置页布局优化：选择器改为 M3 菜单（选中高亮+圆角），行高紧凑，导入/删除按钮与下拉对齐
- [x] 字体加载改用 dart:ui loadFontFromList：支持 ttc 字体集合，去除 services 依赖；字体族名改为纯 ASCII 哈希命名，避免与 Flutter 字体包名冲突

**播放、小窗与画质**
- [x] 实现了类似于[Pilipro](https://github.com/naaammme/pilipro)的应用内小窗功能，感谢原作者naaammme的无私奉献,在实现时参考了其逻辑
- [x] 应用内小窗支持拖动、双击调整大小、横竖屏比例自适应和仿官方控制栏操作
- [x] 应用内小窗增强：收起/展开过渡动画；记住拖动位置与缩放档位；移动端双指捏合和桌面端滚轮连续缩放；直播小窗新增底部控制栏（播放/暂停/刷新），直播卡死时可直接在小窗内自救
- [x] 应用内小窗支持SponsorBlock跳过片段，支持从应用内小窗返回桌面自动进入系统小窗

  演示图片:![应用内小窗演示](https://r2.170529.xyz/PicList/2026/02/IMG_20260222_194923.avif)
- [x] 实现了可以和其他应用同时播放音频的功能
- [x] 播放器新增应用内音量控制功能，并支持在应用内音量模式下增强至 200%
- [x] **自定义视频 CDN 域名与区域节点选择**：视频设置新增 CDN 节点选择器，可自定义视频 CDN 域名、按区域挑选节点，并支持测速对比延迟
- [x] 支持半屏和全屏独立选择默认画质
- [x] 全屏锁定按钮可设置显示在右侧，方便单手操作
- [x] 收藏夹/分P/合集支持随机播放（顺序/倒序/随机三态切换），随机模式下播完不循环
- [x] **倍速上滑锁定**：长按倍速时上滑越线即可锁定，无需一直按着；锁定阈值按播放器实际高度自适应，降低误触发
- [x] 倍速纳入单独视频设置，切换视频或复用播放器时自动重置为默认倍速
- [x] 增强系统媒体控制（通知栏/锁屏）可根据多P/合集/播放列表动态显示上一集/下一集按钮
- [x] **平板端键盘控制**：ESC 全平台返回生效，外接键盘可直接返回上一页；视频页支持方向键/PgUp/PgDn 滚动，长按连续滚动
- [x] 在听视频界面的评论中也实现了根据评论时间戳快速跳转的功能
- [x] 直播超级聊天（SC）卡片支持显示发送时间
- [x] 尝试支持直播心跳功能，用于粉丝团亲密度积累

**字幕、AI 与离线缓存**
- [x] **双语字幕**：支持主字幕和副字幕同时显示，字幕选择面板改为主/副双栏；只有一条字幕时保留旧版单列菜单
- [x] **副字幕样式设置**：副字幕可独立调整字号、全屏字号、字重、描边和背景不透明度，并支持调整主副字幕间距
- [x] **AI 字幕分析功能**：支持自定义 OpenAI 兼容 API 地址和模型、时间戳跳转、模板预设和对话持久化；AI 对话新增无字幕柔性降级策略
- [x] 在保存字幕的功能中添加了选择保存为原始WEBVTT格式和SRT格式的选项
- [x] 离线缓存新增"全部视频 / 文件夹"双视图，支持文件夹管理、手动排序、批量归类和按文件夹顺序播放
- [x] 离线缓存视频支持 CC 字幕下载与离线播放
- [x] 离线缓存播放支持元数据持久化，播放本地缓存时可恢复章节进度条与 SponsorBlock
- [x] 下载页支持导出离线缓存视频到公共 Download 目录，支持单个导出和批量多选（仅 Android）
- [x] 下载页支持继续播放上次播放的视频，也支持多选导出选中的下载条目

**弹幕与屏蔽**
- [x] **增强合并弹幕功能**，添加类[Pakku.js](https://github.com/xmcp/pakku.js)实现，重复弹幕字体随数量而增大，可设置放大阈值和放大速度
- [x] 合并弹幕字号放大功能新增总开关，关闭后合并弹幕与普通弹幕字号一致

  演示图片:![合并弹幕演示](https://r2.170529.xyz/PicList/2026/02/Pakku_Life.avif)
- [x] 增强原有的弹幕屏蔽功能，使用列表式可视化菜单替换了原有的|分割正则，尝试支持了更复杂的正则
- [x] 弹幕屏蔽列表支持导入/导出，方便跨设备迁移、备份或使用 AI 辅助编辑
- [x] **SponsorBlock**：新增"快进到片段中间时跳过"设置，手动拖动进度进入片段时也能自动跳过
- [x] **弹幕密度高能进度条改用高斯核算法** 支持本地根据弹幕的分布情况计算的出高能进度条，提升数据缺失时的可用性

**推荐、动态与评论过滤**
  对于推荐流、动态流和评论的过滤功能，在原有的基础上基于个人习惯和社区反馈进行了增强和调整，增加了更多的过滤条件和应用场景，并优化了过滤列表的编辑体验。
- [x] 推荐流过滤支持标题关键词、UP 名称关键词、分区关键词、屏蔽用户、视频时长、播放量、点赞率和已关注 UP 豁免，首页 app 端推荐还支持屏蔽无权查看视频（如充电专属视频）
- [x] 推荐流过滤器拓展到可选择应用到相关视频、热门视频、分区视频和搜索结果，搜索结果中仅过滤标题关键词和屏蔽用户
- [x] 推荐流新增共享白名单，支持在视频菜单和作者面板中一键加白
- [x] 动态流过滤支持关键词、屏蔽用户、带货动态、无权查看动态和充电专属视频动态；新增 UP 主本人评论和置顶评论的豁免
- [x] 评论过滤支持关键词、屏蔽用户、低等级用户、带货评论、UP 主点赞评论豁免和 UP 主参与回复评论豁免
- [x] App+Web 端推荐流合并模式，可在设置中切换

**动态、搜索与用户信息**
- [x] UP 主空间页和关注列表新增自定义备注功能，并支持在动态页和视频详情页作者名称后显示备注
- [x] **备注替换昵称**：新增全局开关，开启后备注首行替换原昵称显示，覆盖视频卡片、评论区、动态、关注列表、播放页等 13 处名字位
- [x] **楼中楼评论默认排序独立设置**：二级评论可单独设置排序方式，未设置时回退到主楼设置
- [x] 搜索结果新增客户端本地关键词过滤，支持包含关键词和排除关键词（以增强B站比较难用的搜索功能）
- [x] 搜索支持 b23.tv 短链，输入短链可直接跳转对应视频
- [x] 首页 App 端推荐视频卡片新增充电专属角标
- [x] 新增"显示视频推荐理由"设置项，可关闭首页视频卡片的"已关注"等推荐理由显示
- [x] 投币页面支持显示当天已获取经验数与经验上限

**直播增强**
- [x] **直播间粉丝勋章佩戴**：输入面板新增粉丝勋章按钮，MD3E 风格底部面板展示勋章列表，支持佩戴/取消佩戴，自动分页加载
- [x] 直播间 DLNA 投屏，并优先使用 HLS 播放源提升兼容性
- [x] 直播超级聊天（SC）卡片支持设置显示发送时间
- [x] 直播小窗新增底部控制栏，直播卡死时可直接在小窗内自救

**系统集成与桌面增强**
- [x] **Windows 系统媒体控制（SMTC）**：播放视频/音频时接入系统媒体传输控制，支持播放/暂停、上一集/下一集、快进/快退，封面本地加载优先
- [x] **Linux 系统媒体控制（MPRIS）**：接入 audio_service_mpris，支持进度拖动、随机/循环/倍速，桌面环境自动拉取封面
- [x] **音频焦点处理重构**：播放/暂停所有入口统一走底层播放路径，双击中间、底部按钮、键盘空格均参与焦点生命周期；允许与竞品同时播放时也保持豁免

## 适配平台
- [x] Android
- [x] iOS
- [x] Pad
- [x] Windows
- [x] Linux

[![Packaging status](https://repology.org/badge/vertical-allrepos/pilinara.svg)](https://repology.org/project/pilinara/versions)

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
- [x] 其他

## fix

- [x] 番剧分集点赞/投币/收藏
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
  - [x] 视频比例：高度/宽度适应、填充、包含等
     
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
  - [x] 主题模式：亮色/暗色/跟随系统
  - [x] 震动反馈(可选)
  - [x] 高帧率
  - [x] 自动全屏
  - [x] 横屏适配
- [ ] 等等

<br/>

## 下载

可以通过右侧release进行下载或拉取代码到本地进行编译

### Arch Linux

感谢 [@nlsdt](https://github.com/nlsdt) 的打包

#### 推荐：Arch Linux CN 软件源

若还未配置 Arch Linux CN 软件源， [前往 wiki](https://wiki.archlinuxcn.org/zh/Arch_Linux_%E4%B8%AD%E6%96%87%E7%A4%BE%E5%8C%BA%E4%BB%93%E5%BA%93) 进行配置
若已配置，可直接安装：

```bash
sudo pacman -S pilinara
```

#### AUR 安装

- `pilinara`（源码构建）
- `pilinara-bin`（ Release 预编译二进制）

```bash
# 使用 paru 安装
paru -S pilinara-bin
```
```bash
# 使用 yay 安装
yay -S pilinara-bin
```

<br/>

## 声明

此项目（PiliNara）是个人为了兴趣而开发，仅用于学习和测试，请于下载后24小时内删除。
所用API皆从官方网站收集，不提供任何破解内容。
在此致敬原作者：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)
在此致敬上游作者：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
在此致敬上游作者：[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
本仓库做了一些自用修改，感谢原作者的开源精神。

感谢使用


<br/>

## 致谢

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- 等等

<br/>
<br/>
<br/>

## Star History

<a href="https://star-history.dera.page/#Starfallan/PiliNara">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=Starfallan/PiliNara&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=Starfallan/PiliNara" />
   <img alt="Star History Chart" src="https://star-history.dera.page/svg?repos=Starfallan/PiliNara" />
 </picture>
</a>