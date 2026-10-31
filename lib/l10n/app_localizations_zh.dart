// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navTitleSettings => '设置';

  @override
  String get secPinStyle => '标记样式';

  @override
  String get settingsPinModeIconsLabel => '图标式 Pin';

  @override
  String get settingsPinModeColoredLabel => '彩色大头针';

  @override
  String get pinHintIcons => '圆头 Pin 内嵌分类图形，信息量直观。';

  @override
  String get pinHintColored => '无图形纯色大头针，用颜色区分地点类型，地图更简洁。';

  @override
  String get secMapSource => '默认地图源';

  @override
  String get mapHomeTitle => '境内攻略 → 高德矢量';

  @override
  String get mapHomeSub => 'GCJ-02 坐标，已自动 WGS-84 换算';

  @override
  String get mapAbroadTitle => '境外攻略 → OpenStreetMap';

  @override
  String get mapAbroadSub => 'WGS-84，全球可用';

  @override
  String get mapSourceFoot => '按需求规则自动确定：攻略创建在境内用高德，境外用 OSM；地图页可随时手动切换。';

  @override
  String get secZone => '游览区域（聚合）参数';

  @override
  String get zoneRadiusLabel => '游览区域默认半径';

  @override
  String get zoneMinPtsLabel => '单簇最少地点数';

  @override
  String get zoneHint =>
      '少于「最少地点数」的必去点将各自单独成区（单独配色、不连线）。半径 = 圆心到圈边的距离（1 km 半径的圈宽约 2 km，非直径）。市区密集景点建议 1–3km，城市间巡游建议 5–10km。若两个游览区域的范围重叠：成员多者为主区域保持范围，少者自动缩小。';

  @override
  String get secShare => '分享';

  @override
  String get watermarkLabel => '水印文字';

  @override
  String get watermarkHint => '分享照片';

  @override
  String get watermarkHintText =>
      '生成分享文件时，攻略中的每张图片（含封面）都会缩放为低质量副本并烧入上述文字水印（半透明白字黑描边，左下角）。水印不可逆，用于共享图保护；攻略内原图不受影响。';

  @override
  String get secKeys => '服务密钥（选配）';

  @override
  String get amapKeyLabel => '高德 Web 服务 Key（境内检索优先使用）';

  @override
  String get amapKeyHint => '在高德开放平台申请的 Web 服务类型 Key';

  @override
  String get tdtKeyLabel => '天地图 tk（启用天地图瓦片源）';

  @override
  String get tdtKeyHint => '在天地图官网申请的开发者 Key';

  @override
  String get keysFoot =>
      '高德 Web Key 仅用于提升境内地点检索精度；天地图 tk 启用天地图瓦片源。不填写时使用免密钥的 Nominatim 检索，离线地图包不受影响。';

  @override
  String get secCategories => '地点分类';

  @override
  String get secDanger => '危险操作';

  @override
  String get clearAllTitle => '一键清空我的攻略';

  @override
  String get clearAllSub => '删除全部攻略（含标记 / 照片 / 游览区域）与对应图片文件，不可恢复；重启应用会自动恢复演示攻略';

  @override
  String get clearAllDialogTitle => '清空全部攻略？';

  @override
  String get clearAllDialogContent =>
      '将删除当前全部攻略（含标记 / 照片 / 游览区域）及其在应用数据目录中的图片文件，此操作不可恢复。\n\n若要保留某篇攻略，请先在攻略内用「生成分享文件」留档。';

  @override
  String get cancel => '取消';

  @override
  String get confirmClear => '确认清空';

  @override
  String clearedToast(int n) {
    return '已清空 $n 篇攻略（图片文件同步删除）';
  }

  @override
  String get secAbout => '关于';

  @override
  String aboutVersion(String v) {
    return '版本 $v';
  }

  @override
  String get aboutLocalOnly => '本作全部数据仅保存在本机，无云服务';

  @override
  String get aboutMapSources => '底图来源：高德 / 天地图 / OSM / Esri';

  @override
  String get aboutMapSourcesSub => '瓦片仅供个人离线使用，界面保留来源标示';

  @override
  String get secLanguage => '语言';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langChinese => '中文';

  @override
  String get langEnglish => 'English';

  @override
  String get languageHint => '切换即时生效，默认中文。';

  @override
  String get homeSearchHint => '检索标题/简介';

  @override
  String get tooltipSearch => '搜索';

  @override
  String get tooltipCloseSearch => '关闭搜索';

  @override
  String get tooltipMenu => '功能菜单';

  @override
  String get fabNew => '新增';

  @override
  String menuDirLabel(String dir) {
    return '数据目录：$dir';
  }

  @override
  String get dirUnavailable => '不可用';

  @override
  String get menuToggleListView => '列表视图';

  @override
  String get menuToggleGridView => '网格视图';

  @override
  String get menuGallery => '地理相册';

  @override
  String get menuOfflineMap => '离线地图';

  @override
  String get menuLoadShare => '加载分享';

  @override
  String get menuSettings => '系统设置';

  @override
  String get homeEmptyTitle => '攻略本是空的';

  @override
  String get homeEmptyHint => '下面没有任何攻略。\n点击右下角「新增」，把想去的地方标在地图上。';

  @override
  String homeNoResult(String query) {
    return '没有匹配「$query」的攻略记录';
  }

  @override
  String mustVisitBadge(int n) {
    return '$n 必去';
  }

  @override
  String placesUnit(int n) {
    return '$n 地点';
  }

  @override
  String get sharedSuffix => '（分享）';

  @override
  String get noSummaryParen => '（暂无简介）';

  @override
  String get regionDomestic => '境内';

  @override
  String get regionAbroad => '境外';

  @override
  String get guideActionOpenMap => '打开地图';

  @override
  String get guideActionInfo => '攻略信息';

  @override
  String get guideActionDelete => '删除攻略';

  @override
  String get deleteGuideTitle => '删除攻略？';

  @override
  String deleteGuideContent(String title) {
    return '「$title」及其本地图文记录将从攻略本移除。';
  }

  @override
  String get btnDelete => '删除';

  @override
  String deletedToast(String title) {
    return '已删除「$title」（JSON 与本地图文已清理）';
  }

  @override
  String importedToast(String name) {
    return '已导入「$name」';
  }

  @override
  String get importProgressTitle => '导入分享攻略';

  @override
  String get importUnpacking => '正在解包校验分享文件…';

  @override
  String get importAwaitingConfirm => '检测到已导入过，等待确认…';

  @override
  String get importRemapping => '正在重映射与落盘…';

  @override
  String get importCancelling => '正在取消…';

  @override
  String get btnImportAgain => '再次导入';

  @override
  String get importedBeforeTitle => '已导入过该攻略';

  @override
  String importedBeforeContent(String title) {
    return '「$title」已于此前导入过。\n再次导入将生成独立副本（不覆盖现有数据）。';
  }

  @override
  String get importCancelled => '导入已取消';

  @override
  String get importInvalidFile => '不是有效的分享文件';

  @override
  String get importTooLarge => '文件超过 1GB，拒绝导入';

  @override
  String get importFailedTitle => '导入失败';

  @override
  String get importFailedPrefix => '导入失败：';

  @override
  String get btnOk => '好的';

  @override
  String get shareFileTypeLabel => '分享攻略文件';

  @override
  String get createStep1 => '攻略信息';

  @override
  String get createStep2 => '范围与区域';

  @override
  String get createTitleHint => '攻略标题，如：杭州两日游';

  @override
  String get createSummaryHint => '简介（可选）';

  @override
  String get createRegionTitle => '攻略区域';

  @override
  String get createCoverTitle => '封面图片';

  @override
  String get createAddCover => '添加封面图片';

  @override
  String get createNoPhotoPick => '当前平台暂不支持选图';

  @override
  String get createNext => '下一步：选定范围';

  @override
  String get createPrev => '上一步';

  @override
  String get createSkipStart => '跳过，使用在线地图直接开始';

  @override
  String createBanner(String where, String source) {
    return '本攻略属于「$where」，默认地图：$source';
  }

  @override
  String get createWhereChina => '中国境内';

  @override
  String get createWhereAbroad => '中国境外';

  @override
  String get createSourceAmap => '高德矢量';

  @override
  String get createSourceOsm => 'OpenStreetMap';

  @override
  String get regionTileChina => '中国境内';

  @override
  String get regionTileOverseas => '中国境外';

  @override
  String get regionTileChinaDesc => '默认高德地图（GCJ-02 自动换算）';

  @override
  String get regionTileOverseasDesc => '默认 OpenStreetMap（WGS-84）';

  @override
  String get createSearchHint => '检索城市或地点，如：杭州 / 西湖 / 东京';

  @override
  String get createScopeFoot => '已下载的地图包可离线使用；地图页可随时切换在线地图源。选定的城市将作为攻略范围。';

  @override
  String get createHotTitle => '试试这些热门城市（联网检索）';

  @override
  String get createHotFoot =>
      '也可以直接「跳过」——稍后在地图上手动缩放定位。检索结果来自 Nominatim（OpenStreetMap），设置页可配置高德 Key 后境内检索将优先使用高德。';

  @override
  String get createSearchError => '检索失败：请检查网络连接（境内可在设置页配置高德 Key 提升精度）';

  @override
  String get createNoMatch => '未找到匹配地点，换个关键词试试';

  @override
  String get createBtnUseLocal => '使用本地地图';

  @override
  String get createBtnUse => '使用';

  @override
  String get createBtnDownload => '一键下载';

  @override
  String createPackReady(String name) {
    return '「$name」已下载，可免流量使用';
  }

  @override
  String get createDemoDone => '演示下载完成';

  @override
  String get createNoPack => '本区域暂无离线地图包，可使用在线地图';

  @override
  String get createPackFallbackName => '离线地图包';

  @override
  String get legendTitle => '图例';

  @override
  String legendZoneNumbered(int n) {
    return '游览区域 $n';
  }

  @override
  String legendZoneNamed(int n, String name) {
    return '游览区域 $n（$name）';
  }

  @override
  String legendZonePoints(int n) {
    return '$n 点';
  }

  @override
  String get catNameScenic => '景点';

  @override
  String get catNameDining => '餐饮';

  @override
  String get catNameHotel => '住宿';

  @override
  String get catNameShopping => '购物';

  @override
  String get catNameTransport => '交通';

  @override
  String get catNameOther => '其他';

  @override
  String get srcAmapVector => '高德矢量';

  @override
  String get srcAmapSatellite => '高德卫星';

  @override
  String get srcOsm => 'OpenStreetMap';

  @override
  String get srcEsriStreet => 'Esri 街道（免 Key）';

  @override
  String get srcEsriTopo => 'Esri 地形（免 Key）';

  @override
  String get srcEsriGray => 'Esri 浅灰（免 Key）';

  @override
  String get srcEsriSatellite => 'Esri 卫星';

  @override
  String get srcTianditu => '天地图';

  @override
  String get srcKindVector => '矢量底图';

  @override
  String get srcKindSatellite => '卫星影像';

  @override
  String get srcTdtKeySuffix => ' · 需在设置页填入天地图 tk';

  @override
  String get mapTooltipLayers => '图层与照片';

  @override
  String get mapTooltipSource => '地图源';

  @override
  String get mapTooltipMore => '更多';

  @override
  String get mapMenuNotes => '攻略笔记';

  @override
  String get mapMenuZoneParams => '重设参数';

  @override
  String get mapMenuShare => '生成分享';

  @override
  String get mapFabLocate => '定位与照片一并接入';

  @override
  String get mapHintPill => '点按 Pin 查看详情 · 长按地图添加标记';

  @override
  String get mapFabMarkers => '标记';

  @override
  String get layersTitle => '地图图层';

  @override
  String get layerMarkers => '地点标记';

  @override
  String get layerMarkersSub => '各分类色彩 Pin 图标';

  @override
  String get layerZoneCircles => '游览区域范围圈';

  @override
  String get layerZoneCirclesSub => '必去点聚类色带（参数见 ⋮ 菜单重设）';

  @override
  String get layerPhotosTitle => '地理相册 · 照片层';

  @override
  String get layerPhotosSub => 'GPS 照片/视频叠上攻略地图；关闭即纯攻略地图（地理相册页反向同理）';

  @override
  String get recalcTitle => '重新计算游览区域';

  @override
  String get recalcSub => '半径/必去变化后会自动重算；此处手动强刷';

  @override
  String get snackRecalcRunning => '正在重算游览区域…';

  @override
  String get zoneDialogTitle => '重设游览区域参数';

  @override
  String get zoneRadiusDialogTitle => '游览区域半径';

  @override
  String get zoneDialogFoot =>
      '半径 = 圆心到圈边的距离（1 km 半径的圈宽约 2 km），非直径；DBSCAN 以它判定必去点是否聚成同一游览区域。';

  @override
  String get zoneDialogFollowState => '本攻略当前跟随通用设置；重设后仅对本攻略生效。';

  @override
  String get zoneDialogOverridden => '本攻略已重设，可点击「恢复通用设置」还原。';

  @override
  String get snackZoneRestored => '已恢复跟随通用设置，游览区域重算中…';

  @override
  String get btnRestoreGlobal => '恢复通用设置';

  @override
  String get btnApplyRecalc => '应用并重算';

  @override
  String get snackZoneApplied => '游览区域已按新参数重算（仅本攻略生效）';

  @override
  String get srcSheetTitle => '选择地图源';

  @override
  String get srcSheetIntro =>
      '境内攻略默认高德（GCJ-02 自动换算），境外默认 OpenStreetMap。下方列出已下载的离线瓦片包，勾选即用（无网络可用）。';

  @override
  String get srcTagChinaRec => '境内推荐';

  @override
  String get srcTagOverseasRec => '境外推荐';

  @override
  String get srcTagWebNoDownload => 'Web 内不可下';

  @override
  String get srcPacksNone => '（暂无离线包——在「离线地图」页新建下载后这里会出现）';

  @override
  String get offlinePrefix => '[离线]';

  @override
  String tileCountUnit(int n) {
    return '$n 张';
  }

  @override
  String get srcHintEsri => ' · 免密钥，浏览器可直抓';

  @override
  String get srcHintOsm => ' · 境内直连常不可达，下载前先连线测试';

  @override
  String get snackNeedsTdtKey => '天地图需先在「设置 → 服务密钥」填入 tk';

  @override
  String snackPackSwitched(String name) {
    return '已切换到离线包「$name」';
  }

  @override
  String get infoSheetTitle => '攻略信息';

  @override
  String get infoSheetSub => '标题、简介与封面可随时修改，首页卡片即时同步';

  @override
  String get infoTitleHint => '攻略标题';

  @override
  String get infoSummaryHint => '简介';

  @override
  String get infoCoverTitle => '封面图片（可选）';

  @override
  String get infoChangeCover => '更换';

  @override
  String get infoRemoveCover => '移除';

  @override
  String get infoAddCover => '添加封面图片（不添加则使用色块封面）';

  @override
  String get infoSaved => '攻略信息已更新（JSON 与封面已保存）';

  @override
  String get btnSave => '保存';

  @override
  String get editNewTitle => '新增地点';

  @override
  String get editEditTitle => '编辑地点';

  @override
  String get editIconNotSaved => '存储不可用，自定义图标未保存';

  @override
  String get editTitleRequired => '请填写地点名称';

  @override
  String get markerAdded => '标记已添加';

  @override
  String get markerSaved => '修改已保存';

  @override
  String get groupIdentity => '名称与分类';

  @override
  String get editTitleHint => '地点名称，如：西湖 · 断桥';

  @override
  String get groupPinStyle => 'Pin 样式';

  @override
  String get pinUploadCustom => '上传自定义 Pin 图';

  @override
  String get pinChangeIcon => '更换 Pin 图';

  @override
  String get pinResetIcon => '恢复默认图标';

  @override
  String get groupRules => '出行规则';

  @override
  String get mustSwitchTitle => '必去地点';

  @override
  String get mustSwitchSub => '勾选「必去」将参与游览区域聚类与最佳推荐路径；「选去」仅作为备选展示';

  @override
  String get gpsCoordTitle => 'GPS 坐标（WGS-84）';

  @override
  String latNorth(String c) {
    return '北纬 $c';
  }

  @override
  String get latSouth => '南纬';

  @override
  String get lngEast => '东经';

  @override
  String get lngWest => '西经';

  @override
  String get copyCoords => '复制坐标';

  @override
  String get coordsCopied => '坐标已复制';

  @override
  String get repickOnMap => '重新在地图上点选';

  @override
  String get verifyNav => '验证导航';

  @override
  String get groupDetails => '图文详情';

  @override
  String get editDescHint => '记录开放时间、口味推荐、避坑小贴士……';

  @override
  String get groupPhotos => '位置照片';

  @override
  String get addPhoto => '添加照片';

  @override
  String get groupLinks => '相关链接';

  @override
  String get linkInvalid => '该链接无效';

  @override
  String get addLink => '添加链接';

  @override
  String get noLinks => '未添加链接';

  @override
  String get linkDialogTitle => '添加链接';

  @override
  String get linkNameHint => '链接名称，如：官方订票';

  @override
  String get linkDefaultName => '链接';

  @override
  String get urlRequired => '请填写 URL';

  @override
  String get btnAdd => '添加';

  @override
  String get mustVisitTag => '必去';

  @override
  String get optionalTag => '选去';

  @override
  String photosSection(int n) {
    return '位置照片（$n）';
  }

  @override
  String get noPhotosHint => '暂无照片——点「编辑详情」添加图文。';

  @override
  String get navHere => '导航到这里';

  @override
  String get editDetails => '编辑详情';

  @override
  String get deleteMarkerTitle => '删除标记？';

  @override
  String deleteMarkerContent(String title) {
    return '「$title」及其图文记录将被移除。';
  }

  @override
  String markerDeletedToast(String title) {
    return '已删除「$title」';
  }

  @override
  String drawerTitle(int n) {
    return '标记列表（$n）';
  }

  @override
  String get filterAll => '全部';

  @override
  String get sortCategory => '分类';

  @override
  String get sortZone => '游览区域';

  @override
  String get sortTime => '时间';

  @override
  String get drawerEmpty => '没有符合条件的标记';

  @override
  String imageCount(int n) {
    return '$n 图';
  }

  @override
  String get pickPointTitle => '在地图上重新选点';

  @override
  String get pickConfirm => '确定这个位置';

  @override
  String get navAmapFail => '未能打开地图，坐标已复制到剪贴板';

  @override
  String get navUrlFail => '无法打开链接（浏览器/平台限制）';

  @override
  String get tilesTitle => '离线地图';

  @override
  String get fabNewPack => '新建下载包';

  @override
  String get deletePackTitle => '删除离线包？';

  @override
  String deletePackContent(String name, int n) {
    return '「$name」的 $n 张瓦片文件将被删除并释放空间，对应的攻略底图将不再命中。';
  }

  @override
  String packDeletedToast(String name) {
    return '已删除「$name」，空间已释放';
  }

  @override
  String get tilesEmptyTitle => '还没有离线包';

  @override
  String get tilesEmptyHint => '右下角「新建下载包」框选区域与级数即可下载';

  @override
  String get bannerTitle => '本地瓦片包';

  @override
  String get bannerSub => '框选范围与缩放级别下载后，无网络也可打开该区域地图；删除即释放空间。';

  @override
  String get tilesFoot =>
      '桌面端：境内建议高德源（细节好，GCJ-02 框选自动换算），境外 OSM / Esri；浏览器端：首选 Esri 系列（免 Key，高德被 CORS 拦、OSM 境内常不可达）。缩放每 +1 瓦片约 ×4 倍，大范围高级别请谨慎；下载前可用「连线测试」验证可达性。';

  @override
  String dateMthDy(String m, String d) {
    return '$m月$d日';
  }

  @override
  String completedOn(String date) {
    return '完成于 $date';
  }

  @override
  String get menuRefill => '重新下载缺片';

  @override
  String get snackRefillUnavailable => '增量补载会在 M6 后按需开放';

  @override
  String get wizardTitle => '新建离线瓦片包';

  @override
  String get stepChooseSource => '选择地图源';

  @override
  String get stepSelectArea => '框选下载范围';

  @override
  String get stepChooseZoom => '选择缩放级别';

  @override
  String get stepConfirm => '确认并下载';

  @override
  String get wizardNeedRange => '请先在地图上点选两个对角点划定范围';

  @override
  String get rangeTooSmall => '范围过小或级别过低，请调整范围/级数';

  @override
  String get hugeConfirmTitle => '范围较大，确认下载？';

  @override
  String hugeConfirmContent(int n, String mb) {
    return '共 $n 张瓦片（约 $mb MB~更高）。耗时取决于网络，可随时取消，已下载部分保留可用。';
  }

  @override
  String get btnRethink => '再想想';

  @override
  String get btnContinueDownload => '继续下载';

  @override
  String progressInit(int n) {
    return '0 / $n · 并发 4 · 重试 2';
  }

  @override
  String progressText(int done, int total, String mb) {
    return '$done / $total · $mb MB（已下载保留，可续传）';
  }

  @override
  String get cancelReasonWebCgj =>
      '浏览器内被高德源跨域（CORS）拦截：改用 Esri 源，或用 Windows 桌面端下载高德源';

  @override
  String get cancelReasonWeb => '浏览器内请求被目标站点跨域（CORS）拦截或断网，可换 OSM 源试试';

  @override
  String get cancelReasonOffline => '连续请求全部失败（可能是断网/地址拒访），请检查网络后重试';

  @override
  String get cancelledKept => '已取消（已落盘部分保留）';

  @override
  String reportStats(String reason, int ok, int skip, int fail) {
    return '$reason：成功 $ok · 跳过 $skip · 失败 $fail';
  }

  @override
  String get snackAbortedKept => '已中断，已落盘部分保留可续传（未写清单）';

  @override
  String downloadedNoneMsg(int n) {
    return '未下载到任何瓦片：$n 片失败，请检查网络';
  }

  @override
  String get snackNoneDownloaded => '未下载到任何瓦片，请检查网络后重试';

  @override
  String get manifestFail => '清单写入失败（存储配额？），瓦片已保留';

  @override
  String get doneLabel => '下载完成';

  @override
  String get donePartial => '完成（含失败片）';

  @override
  String doneMsgLine(String what, String report, int secs) {
    return '$what：$report · $secs 秒';
  }

  @override
  String snackPackReady(int n) {
    return '离线包已就绪（$n 张），可在攻略地图源中勾选使用';
  }

  @override
  String snackPartialFail(int n) {
    return '部分瓦片失败（$n），可重新下载续传';
  }

  @override
  String get packNameUnnamed => '未命名地图包';

  @override
  String get needRangeForProbe => '请先在框选步骤选定范围';

  @override
  String get probing => '正在连线测试（取 1 片实测）…';

  @override
  String get extraWebCgj => '（浏览器版本中高德源会被 CORS 拦截）';

  @override
  String probeOk(String status, int ms, String extra) {
    return '✅ 连线正常：HTTP $status · $ms 毫秒 $extra';
  }

  @override
  String probeFailWeb(String status, int ms) {
    return '❌ 不通（HTTP $status · $ms 毫秒）—— 换 Esri/OSM 源试试，或用 Windows 桌面端';
  }

  @override
  String probeFailDesktop(String status, int ms) {
    return '❌ 不通（HTTP $status · $ms 毫秒）—— 请检查网络';
  }

  @override
  String srcRecommendFoot(String note) {
    return '境内建议高德源（$note），境外建议 OSM / Esri。';
  }

  @override
  String get srcNoteGcj => 'GCJ-02 框选点已自动换算';

  @override
  String get srcNoteWgs => 'WGS-84';

  @override
  String get webPreviewNote =>
      '浏览器预览：首选 Esri 系列（免 Key），高德源会被 CORS 拦截，OSM 官方源境内常不可达；不确定就先「连线测试」。';

  @override
  String get areaDone => '已选定对角两点';

  @override
  String get areaHint => '在下方地图点选两个对角点';

  @override
  String get btnClear => '清除';

  @override
  String pointLabelA(String value) {
    return 'A：$value';
  }

  @override
  String pointLabelB(String value) {
    return 'B：$value';
  }

  @override
  String get notPicked => '未选择';

  @override
  String get zoomFootStep => 'z12–16 适合市内街道浏览；级别每 +1 瓦片约 ×4，注意容量与下载时长。';

  @override
  String get rowMapSource => '地图源';

  @override
  String get rowCoordSys => '坐标系';

  @override
  String get coordRowGcj => 'GCJ-02（框选点已换算）';

  @override
  String get rowRange => '范围';

  @override
  String get rowZoom => '缩放级别';

  @override
  String get rowManifest => '实际清单';

  @override
  String manifestValue(int n, String mb) {
    return '$n 张 · 约 $mb MB';
  }

  @override
  String get manifestPending => '请先完成范围选择';

  @override
  String get probeBtnValue => '连线测试（下载前实测 1 片可达性，几秒出结果）';

  @override
  String get webCgjWarning =>
      '浏览器版本中高德源不支持跨域抓取（CORS），下载会失败。请改用 Esri 源，或用 Windows 桌面端下载高德源。';

  @override
  String get startDownload => '开始下载';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get btnNext => '下一步';

  @override
  String videoDupPart(int n) {
    return ' · 内容重复跳过 $n';
  }

  @override
  String videoFailPart(int n) {
    return ' · 处理失败 $n（请重试或换格式）';
  }

  @override
  String get videoFullPart => ' · 已达到相册取样上限';

  @override
  String get videoTailPart => ' —— 请点开视频（相册库）补写地理位置';

  @override
  String videoInsertBanner(
    int imported,
    String dup,
    String fail,
    String full,
    String tail,
  ) {
    return '视频插入：新增 $imported$dup$fail$full$tail';
  }

  @override
  String get removePhotoTitle => '剔除照片';

  @override
  String removeGuidePhotoContent(String name) {
    return '「$name」将从地理相册与攻略地图照片同时移除（重新导入才会恢复）。';
  }

  @override
  String get photoUnnamed => '未命名照片';

  @override
  String get removeLedgerPhotoContent => '该照片将从地理相册与地图照片移除（重新加入才会恢复）。';

  @override
  String get removePhotoBtn => '剔除';

  @override
  String get locateFailSnack => '未能获取定位（浏览器需允许位置权限）';

  @override
  String get scanFolderTitle => '批量导入相册文件夹';

  @override
  String get scanFolderLabel => '本地文件夹路径';

  @override
  String get scanFolderHint => 'C:\\Users\\你的用户名\\Pictures\\旅行照片';

  @override
  String get startImport => '开始导入';

  @override
  String batchImportStats(int imported, int duplicates) {
    return '批量导入：新增 $imported · 重复跳过 $duplicates';
  }

  @override
  String noGpsTail(int n) {
    return '，无定位 $n';
  }

  @override
  String capReachedPart(int n) {
    return '（达到取样上限 $n）';
  }

  @override
  String curateImportStats(int imported, int duplicates) {
    return '精选加入：新增 $imported · 重复跳过 $duplicates';
  }

  @override
  String get insertVideosTitle => '插入视频';

  @override
  String get insertVideosContent =>
      '视频从本机文件插入地理相册账本。\n插入手动定义地理位置：入册后需要在相册库中逐个为视频点选地图补写拍摄位置（视频无 EXIF 定位）。\n\n批量：一次多选窗口挑一批；逐个：一支一支选，随时取消。\n两种方式入册后效果相同。';

  @override
  String get pickOneByOne => '逐个挑选';

  @override
  String get pickBatch => '批量多选';

  @override
  String get videoTypeGroup => '视频';

  @override
  String get collectedOne => '已收集 1 支视频';

  @override
  String get pickNextAsk => '继续挑下一支吗？';

  @override
  String get startInsertNow => '就这些，开始插入';

  @override
  String get keepPicking => '继续挑选下一支';

  @override
  String pickVideoFail(String err) {
    return '选择视频失败：$err';
  }

  @override
  String get removedToast => '已剔除';

  @override
  String geoWritten(String coords) {
    return '已写入地理标识 $coords';
  }

  @override
  String get albumLibTooltip => '相册库（全部照片 · GPS 状态 · 显示开关）';

  @override
  String get menuBatchImport => '批量导入';

  @override
  String get menuCurate => '精选照片';

  @override
  String get menuInsertVideos => '插入视频';

  @override
  String get noticeEmpty => '地理相册尚未加入照片——右上角 ⋮ 批量导入或精选加入';

  @override
  String noticeOnMap(int n) {
    return '$n 张已上图';
  }

  @override
  String noticeMissing(int n) {
    return '$n 张无 GPS 暂不上图';
  }

  @override
  String noticeAllShown(int n) {
    return '$n 张照片已上图 · 放大地图查看更多';
  }

  @override
  String get baseMapAmap => '底图 © 高德地图';

  @override
  String get baseMapEsri => '底图 © Esri（高德源不可达，已自动切换）';

  @override
  String get baseMapOsm => '底图 © OpenStreetMap（高德/Esri 均不可达）';

  @override
  String baseSwitchSnack(String name) {
    return '高德底图不可达，已切换：$name';
  }

  @override
  String get albumLibTitle => '相册库';

  @override
  String get albumLibEmpty => '相册库还是空的';

  @override
  String get albumLibEmptyHint => '回到地理相册，用 ⋮ 菜单「批量导入 / 精选加入」添加';

  @override
  String get sourceAlbumImport => '相册导入';

  @override
  String sourceGuide(String title) {
    return '攻略 · $title';
  }

  @override
  String get sourceGuidePhoto => '攻略照片';

  @override
  String get geoUpdated => '已更新地理定位';

  @override
  String currentGeoLabel(String coords) {
    return '当前定位 $coords';
  }

  @override
  String get editGeoTitle => '修改地理定位';

  @override
  String get editGeoHint => '进入选点地图重新选择，确认后覆盖此条当前位置';

  @override
  String videoRowTitle(String dur) {
    return '视频$dur';
  }

  @override
  String rowGps(String coords) {
    return 'GPS $coords（长按行可修改定位）';
  }

  @override
  String get rowNoGeoVideo => '无定位（点行进入查看器补写拍摄位置）';

  @override
  String get rowNoGps => '无 GPS（查看照片时可补标识）';

  @override
  String get curateTitle => '精选加入（勾选要入册的照片）';

  @override
  String curateAdd(int n) {
    return '加入 $n 张';
  }

  @override
  String get viewPhotosTitle => '浏览照片';

  @override
  String playWithDuration(String dur) {
    return '播放 · $dur';
  }

  @override
  String get playVideoBtn => '播放视频';

  @override
  String get geoTagTitle => '设置地理标识';

  @override
  String get pickHint => '缩放地图到合适区域后，点击目标位置落点';

  @override
  String get pickedHint => '已落点（可继续点击微调位置）';

  @override
  String get noLocationYet => '尚未选择位置';

  @override
  String get confirmLocation => '确认该位置';

  @override
  String get removeThisPhoto => '剔除该张';

  @override
  String get photoWallNoGuides => '暂无攻略';

  @override
  String get mapPhotosSuffix => ' · 地图照片';

  @override
  String importParsing(String n) {
    return '正在解析 EXIF 与生成缩略图…（$n 张）';
  }

  @override
  String importAllDup(String n) {
    return '所选择的都是重复照片（$n 张），未重复导入';
  }

  @override
  String importFail(String err) {
    return '导入失败：$err';
  }

  @override
  String get switchGuideTip => '切换攻略';

  @override
  String get sortNewTip => '拍摄时间：新→旧';

  @override
  String get sortOldTip => '拍摄时间：旧→新';

  @override
  String get photoListTip => '照片清单（已定位/未定位）';

  @override
  String get importPhotosTip => '导入照片';

  @override
  String get layerPhotosOnly => '仅照片';

  @override
  String get layerWithMarkers => '+标记';

  @override
  String markerOnPhotoMap(String title) {
    return '标记「$title」— 在攻略地图页查看详情';
  }

  @override
  String photoListStats(String total, String located, String unlocated) {
    return '照片 $total 张 · 已定位 $located · 未定位 $unlocated';
  }

  @override
  String get sectionUnlocated => '未定位';

  @override
  String boundPrefix(String title) {
    return '绑 $title · ';
  }

  @override
  String get noLocBindTip => '无定位（点击绑定标记）';

  @override
  String get bindBtn => '绑定';

  @override
  String get renamePhotoTitle => '重命名照片';

  @override
  String get renamePhotoHint => '如「日出 · 龙井茶园」（空则显示拍摄时间）';

  @override
  String get nameReset => '已恢复默认名';

  @override
  String renamedTo(String name) {
    return '已改名：$name';
  }

  @override
  String get deletePhotoTitle => '删除照片';

  @override
  String deletePhotoContent(String title) {
    return '将从攻略删除该照片，并删除原图/缩略图文件。\n\n$title';
  }

  @override
  String get photoDeleted => '照片已删除（文件已清理）';

  @override
  String get unboundToast => '已解除绑定';

  @override
  String boundToast(String name) {
    return '已绑定：$name';
  }

  @override
  String get renameTip => '重命名';

  @override
  String latLngLine(String lat, String lng) {
    return '北纬 $lat · 东经 $lng';
  }

  @override
  String noExifLine(String tail) {
    return '无 EXIF 定位$tail';
  }

  @override
  String get exifFollowTail => '（跟随绑定标记）';

  @override
  String get changeBindBtn => '更改绑定';

  @override
  String boundMarkerLine(String title, String tail) {
    return '绑定标记：$title$tail';
  }

  @override
  String get shownAtMarkerTail => '（显示在标记位置）';

  @override
  String get videoPlayTitle => '视频播放';

  @override
  String playerError(String msg) {
    return '播放出错：$msg';
  }

  @override
  String pathError(String msg) {
    return '文件路径不可用：$msg';
  }

  @override
  String get btnBack => '返回';

  @override
  String get bindToMarker => '绑定到标记';

  @override
  String get changeBindTitle => '更改绑定的标记';

  @override
  String get bindNoMarkers => '攻略还没有标记，先在地图页添加';

  @override
  String distToShot(String dist) {
    return '距拍摄点 $dist';
  }

  @override
  String get unbindLine => '解除绑定';

  @override
  String get notesTitle => '攻略笔记';

  @override
  String get notesEmptyHint => '攻略内尚无地点，先在地图上添加：长按地图新建标记';

  @override
  String get viewOnMapTip => '在攻略地图中查看';

  @override
  String zoneCountChip(String n) {
    return '$n 游览区域';
  }

  @override
  String scenicCountChip(String n) {
    return '$n 游览点';
  }

  @override
  String get recommendedTail => ' · 推荐住宿';

  @override
  String zoneLabelN(String n) {
    return '游览区域 $n';
  }

  @override
  String zoneRange(String r, String a) {
    return '半径 $r · 面积约 $a k㎡';
  }

  @override
  String kmFromStart(String d) {
    return '距起点 $d km';
  }

  @override
  String get zoneEmpty => '本片区暂无登记地点';

  @override
  String get secDiningRec => '餐饮推荐';

  @override
  String get secShoppingRec => '购物推荐';

  @override
  String get secScenic => '景点';

  @override
  String get secDining => '餐饮';

  @override
  String get secShopping => '购物';

  @override
  String get secOther => '其他';

  @override
  String photosTotalN(String n) {
    return '共 $n 图';
  }

  @override
  String get noPhotoYet => '暂无照片';

  @override
  String get mustVisitStar => '  ★必去';

  @override
  String get descMissing => '图文暂缺';

  @override
  String get navBtnShort => '导航';

  @override
  String get stayHead => '本次住宿 · 游览起点';

  @override
  String get stayPlan => '从近到远安排各片区';

  @override
  String get otherRecTitle => '其他推荐（不在任何片区圈内）';

  @override
  String get flatBanner =>
      '本攻略暂无必去点，未划分游览区域：以下为全部登记地点的类别平铺（住宿置顶）。在地图上把地点标为「必去」后，攻略笔记将自动按游览区域编排。';

  @override
  String get preparing => '准备…';

  @override
  String estMb(String n) {
    return '约 $n MB';
  }

  @override
  String estKb(String n) {
    return '约 $n KB';
  }

  @override
  String exportStats(String m, String ph, String v, String cl) {
    return '标记 $m · 照片 $ph · 视频 $v · 片区 $cl';
  }

  @override
  String estTotal(String est) {
    return '预计体积：$est';
  }

  @override
  String get includePhotosTitle => '包含攻略照片（低质量副本 + 水印）';

  @override
  String get wmFromSettings => '水印来自设置（可自定义）';

  @override
  String get videoTransTail => '；视频转 ≤720p 并烧录水印';

  @override
  String get noPhotosDesc => '仅导出标记 / 片区 / 文本，体积最小';

  @override
  String get receiverNote => '接收方导入后可完整查看攻略；分享的照片与视频仅存于攻略内，不会进入其地理相册。';

  @override
  String get genBtn => '生成 .tgshare 文件';

  @override
  String get workingTitle => '正在生成分享文件…';

  @override
  String progressLine(String d, String n, String label) {
    return '已处理 $d/$n：$label';
  }

  @override
  String get doneTitle => '生成完成';

  @override
  String get doneNote => '把该文件发给任何装有本应用的朋友，其「导入分享攻略」即可打开；也可留作您的永久备份。';

  @override
  String get btnFinish => '完成';

  @override
  String get failedTitle => '生成失败';

  @override
  String get retryBtn => '返回重试';

  @override
  String get progStructured => '结构化数据';

  @override
  String get progManifest => '清单';

  @override
  String get progCover => '封面';

  @override
  String progPhoto(String name) {
    return '照片 $name';
  }

  @override
  String progThumb(String name) {
    return '缩略 $name';
  }

  @override
  String progImage(String name) {
    return '插图 $name';
  }

  @override
  String progTranscode(String name) {
    return '视频转码 $name';
  }

  @override
  String progVideo(String name) {
    return '视频 $name';
  }

  @override
  String get progWriteCover => '正在写入封面';

  @override
  String progImportImage(String name) {
    return '正在传入插图：$name';
  }

  @override
  String progGenMap(String name) {
    return '正在生成地图：$name';
  }

  @override
  String progImportPhoto(String name) {
    return '正在传入照片：$name';
  }

  @override
  String progGenThumb(String name) {
    return '正在生成缩略：$name';
  }

  @override
  String progImportVideo(String name) {
    return '正在传入视频：$name';
  }

  @override
  String progAttachGuide(String name) {
    return '正在挂入攻略：$name';
  }

  @override
  String get progRebuildZones => '正在重建片区';

  @override
  String get progWriteLibrary => '正在写入攻略库';

  @override
  String get guideFallback => '攻略';

  @override
  String webDownloadDone(String filename) {
    return '已触发浏览器下载：$filename';
  }

  @override
  String get unknownPlace => '未知地点';

  @override
  String get webStorageLabel => '浏览器本地存储（Web 预览降级）';

  @override
  String get ledgerFull => '白板已满';

  @override
  String get nothingImported => '没有可导入的照片';

  @override
  String dirNotFound(String path) {
    return '目录不存在：$path';
  }

  @override
  String get folderNoPhotos => '目录里没有找到照片（jpg/png）';

  @override
  String get folderAllFailed => '目录里的照片都读取失败';

  @override
  String get folderReadFail => '读取失败（目录不可访问？）';

  @override
  String get webScanUnsupported => '浏览器端不支持目录扫描：请用「手动导入」，或在 Windows 桌面端使用';

  @override
  String autoImportStats(int imported, int duplicates) {
    return '自动读取：新增 $imported · 重复跳过 $duplicates';
  }

  @override
  String assignedTail(int n) {
    return '，归属攻略 $n';
  }

  @override
  String capAdjustTail(int n) {
    return '（达到取样上限 $n，可在设置里调大）';
  }

  @override
  String photoImportStats(int imported, int located, int noGps) {
    return '导入 $imported 张（定位 $located · 无定位 $noGps）';
  }

  @override
  String photoDupTail(int duplicates) {
    return '，重复跳过 $duplicates 张';
  }

  @override
  String dlReport(int ok, int skip, int fail, String mb) {
    return '成功 $ok · 跳过(已存在) $skip · 失败 $fail · $mb MB';
  }

  @override
  String get shareExportTitle => '生成分享文件';

  @override
  String get shareModeLabel => '打包模式';

  @override
  String get modeWatermarked => '水印低质版';

  @override
  String get modeOriginal => '原片高清版';

  @override
  String get modeWatermarkedDesc =>
      '照片 ≤960px / 封面 ≤1280px / 视频转 ≤720p，全部烧录水印（不可逆）';

  @override
  String get modeOriginalDesc =>
      '照片与视频按原件字节入包（不缩放、不转码、无水印）；包体上限 1GB；原件全程只读，超限时可剔除条目或降质打包';

  @override
  String get webOriginalUnsupported => 'Web 为降级存储实现，原片模式仅桌面与移动端可用';

  @override
  String get originalVideosNote => '原件字节直接入包（不缩码、不转码、无水印）；可先筛掉不需要的照片/视频';

  @override
  String estOriginalCap(String size) {
    return '原片合计：$size（上限 1GB）';
  }

  @override
  String sizeGb(String n) {
    return '$n GB';
  }

  @override
  String get filterMediaBtn => '筛选打包内容';

  @override
  String filterMediaBtnOn(String n) {
    return '筛选打包内容（已剔除 $n）';
  }

  @override
  String get filterMediaTitle => '选择要打包的照片与视频';

  @override
  String filterIncluded(String n, String total) {
    return '已选 $n/$total（未勾选的不进入分享包）';
  }

  @override
  String get tooBigTitle => '包体超出上限';

  @override
  String tooBigMsg(String size) {
    return '原片包预计 $size，超过 1 GB 上限。请剔除部分照片 / 视频，或选择下方降质档后按「降质打包」。';
  }

  @override
  String get tooBigFilter => '去筛选';

  @override
  String get tooBigDegrade => '降质打包';

  @override
  String get degradeHighLabel => '高清优先（长边 2048 · q85）';

  @override
  String get degradeSmallLabel => '体积优先（长边 1080 · q80）';

  @override
  String get degradeNote =>
      '降质只作用于本次打包的副本：临时副本在内存/临时目录生成，打包完成后即清除；相册与攻略中的原图不会被改动。';

  @override
  String degradeApplied(String tier) {
    return '降质档：$tier';
  }

  @override
  String get receiverNoteOriginal =>
      '接收方导入后可完整查看攻略并可再次导出原片；分享的照片与视频仅存于攻略内，不会进入其地理相册。';

  @override
  String get doneNoteOriginal => '原片包不含水印与降质处理；可发给朋友共享原画质，也可留作永久备份副本。';

  @override
  String get removeRowTooltip => '剔除（保留原文件）';

  @override
  String get removedToastKeep => '已剔除，原文件保留';

  @override
  String get undoBtn => '撤销';

  @override
  String removedCountSuffix(int n) {
    return '（已剔除 $n）';
  }

  @override
  String get removedActionTip => '管理已剔除';

  @override
  String get removedSheetHint => '已剔除的条目不删除原文件，可在此恢复显示';

  @override
  String get restoreBtn => '恢复显示';

  @override
  String get restoreAllBtn => '全部恢复';

  @override
  String restoredToastN(int n) {
    return '已恢复 $n 条显示';
  }

  @override
  String get removedListEmpty => '没有已剔除的条目';

  @override
  String get menuExportAll => '全量导出';

  @override
  String get bundleTitle => '全量导出';

  @override
  String get bundleSubtitle => '把攻略本全部攻略打包成一个文件（迁移 / 备份用）';

  @override
  String bundleIntroCount(String n) {
    return '共 $n 篇攻略，将逐个以原片模式打包';
  }

  @override
  String get bundleIntroNote =>
      '逐篇导出最高画质（照片与视频原件直通——不缩放、不转码、不加水印），不限制总体积，最终打包为单个 .tgbundle 大包。用于文件迁移与多设备共享；导入端从「加载分享」选择该文件即可整本恢复（已导入过的攻略会自动跳过）。';

  @override
  String bundleLedgerHint(String n) {
    return '其中 $n 篇攻略挂有相册归属的照片 / 视频，将一并打包';
  }

  @override
  String get bundleBtnStart => '开始全量导出';

  @override
  String get bundlePreparing => '正在准备…';

  @override
  String bundlePacking(String k, String n, String title) {
    return '正在打包第 $k/$n 篇：$title';
  }

  @override
  String get bundleFileName => 'AtmaBook_全量备份';

  @override
  String get bundleDoneTitle => '全量导出完成';

  @override
  String bundleDoneDetail(String path, String size) {
    return '已保存到：$path\n总体积 $size';
  }

  @override
  String get bundleFailedTitle => '全量导出失败';

  @override
  String get bundleFailedEmpty => '全量导出失败（没有可打包的攻略）';

  @override
  String get webBundleUnsupported => 'Web 端无文件系统，全量导出与导入请在桌面 / 移动端使用。';

  @override
  String get importBundleProg => '正在导入全量包…';

  @override
  String importBundleItem(String title) {
    return '正在导入：$title';
  }

  @override
  String get importBundleInvalid => '不是有效的全量导出包（.tgbundle）';

  @override
  String importBundleReport(String ok, String skip, String fail) {
    return '全量导入：成功 $ok 篇 · 已存在跳过 $skip 篇 · 失败 $fail 篇';
  }

  @override
  String get categoriesColorLabel => '颜色';

  @override
  String get categoriesIconLabel => '图标';

  @override
  String get categoriesNameLabel => '名称';

  @override
  String get categoriesNameHint => '分类名称，如：温泉、垂钓';

  @override
  String get categoriesNewTitle => '新建分类';

  @override
  String get categoriesResetDefault => '恢复默认样式';

  @override
  String get categoriesNameRequired => '请填写分类名称';

  @override
  String get categoriesDeleteTitle => '删除该分类？';

  @override
  String get categoriesDeleteWarn => '删除后，已使用该分类的标记将回退为「其他」分类。';

  @override
  String get categoriesSavedSnack => '分类样式已保存';

  @override
  String get categoriesAddedSnack => '分类已创建';

  @override
  String get categoriesAddSub => '新建自定义分类（名称 + 配色 + 图标）';

  @override
  String get categoriesImgLabel => '图片图标（本地图片替代 Pin 图标）';

  @override
  String get categoriesImgUpload => '上传图片';

  @override
  String get categoriesImgReplace => '替换图片';

  @override
  String get categoriesImgClear => '撤下图片';

  @override
  String get categoriesImgEmpty => '未上传 · 使用上面选中的内置图标';

  @override
  String get categoriesImgCurrent => '已上传 · 地图 Pin 与各界面将显示该图片';

  @override
  String get categoriesImgHint =>
      '需 1:1 正方形图片（不超过 512×512）；上传后替代 Pin 图标显示，尺寸与内置图标一致；选内置图标或撤下即可还原。';

  @override
  String get categoriesImgNotSquare => '图片需为 1:1 正方形（当前边长不等），请裁成方形后再上传';

  @override
  String get categoriesImgSaved => '图片图标已保存，保存后生效';

  @override
  String get categoriesImgFail => '图片读取/保存失败，请换一张图片';

  @override
  String categoriesColorHex(String hex) {
    return '颜色 #$hex';
  }
}
