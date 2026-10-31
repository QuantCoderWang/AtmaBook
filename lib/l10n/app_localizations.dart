import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @navTitleSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navTitleSettings;

  /// No description provided for @secPinStyle.
  ///
  /// In zh, this message translates to:
  /// **'标记样式'**
  String get secPinStyle;

  /// No description provided for @settingsPinModeIconsLabel.
  ///
  /// In zh, this message translates to:
  /// **'图标式 Pin'**
  String get settingsPinModeIconsLabel;

  /// No description provided for @settingsPinModeColoredLabel.
  ///
  /// In zh, this message translates to:
  /// **'彩色大头针'**
  String get settingsPinModeColoredLabel;

  /// No description provided for @pinHintIcons.
  ///
  /// In zh, this message translates to:
  /// **'圆头 Pin 内嵌分类图形，信息量直观。'**
  String get pinHintIcons;

  /// No description provided for @pinHintColored.
  ///
  /// In zh, this message translates to:
  /// **'无图形纯色大头针，用颜色区分地点类型，地图更简洁。'**
  String get pinHintColored;

  /// No description provided for @secMapSource.
  ///
  /// In zh, this message translates to:
  /// **'默认地图源'**
  String get secMapSource;

  /// No description provided for @mapHomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'境内攻略 → 高德矢量'**
  String get mapHomeTitle;

  /// No description provided for @mapHomeSub.
  ///
  /// In zh, this message translates to:
  /// **'GCJ-02 坐标，已自动 WGS-84 换算'**
  String get mapHomeSub;

  /// No description provided for @mapAbroadTitle.
  ///
  /// In zh, this message translates to:
  /// **'境外攻略 → OpenStreetMap'**
  String get mapAbroadTitle;

  /// No description provided for @mapAbroadSub.
  ///
  /// In zh, this message translates to:
  /// **'WGS-84，全球可用'**
  String get mapAbroadSub;

  /// No description provided for @mapSourceFoot.
  ///
  /// In zh, this message translates to:
  /// **'按需求规则自动确定：攻略创建在境内用高德，境外用 OSM；地图页可随时手动切换。'**
  String get mapSourceFoot;

  /// No description provided for @secZone.
  ///
  /// In zh, this message translates to:
  /// **'游览区域（聚合）参数'**
  String get secZone;

  /// No description provided for @zoneRadiusLabel.
  ///
  /// In zh, this message translates to:
  /// **'游览区域默认半径'**
  String get zoneRadiusLabel;

  /// No description provided for @zoneMinPtsLabel.
  ///
  /// In zh, this message translates to:
  /// **'单簇最少地点数'**
  String get zoneMinPtsLabel;

  /// No description provided for @zoneHint.
  ///
  /// In zh, this message translates to:
  /// **'少于「最少地点数」的必去点将各自单独成区（单独配色、不连线）。半径 = 圆心到圈边的距离（1 km 半径的圈宽约 2 km，非直径）。市区密集景点建议 1–3km，城市间巡游建议 5–10km。若两个游览区域的范围重叠：成员多者为主区域保持范围，少者自动缩小。'**
  String get zoneHint;

  /// No description provided for @secShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get secShare;

  /// No description provided for @watermarkLabel.
  ///
  /// In zh, this message translates to:
  /// **'水印文字'**
  String get watermarkLabel;

  /// No description provided for @watermarkHint.
  ///
  /// In zh, this message translates to:
  /// **'分享照片'**
  String get watermarkHint;

  /// No description provided for @watermarkHintText.
  ///
  /// In zh, this message translates to:
  /// **'生成分享文件时，攻略中的每张图片（含封面）都会缩放为低质量副本并烧入上述文字水印（半透明白字黑描边，左下角）。水印不可逆，用于共享图保护；攻略内原图不受影响。'**
  String get watermarkHintText;

  /// No description provided for @secKeys.
  ///
  /// In zh, this message translates to:
  /// **'服务密钥（选配）'**
  String get secKeys;

  /// No description provided for @amapKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'高德 Web 服务 Key（境内检索优先使用）'**
  String get amapKeyLabel;

  /// No description provided for @amapKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'在高德开放平台申请的 Web 服务类型 Key'**
  String get amapKeyHint;

  /// No description provided for @tdtKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'天地图 tk（启用天地图瓦片源）'**
  String get tdtKeyLabel;

  /// No description provided for @tdtKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'在天地图官网申请的开发者 Key'**
  String get tdtKeyHint;

  /// No description provided for @keysFoot.
  ///
  /// In zh, this message translates to:
  /// **'高德 Web Key 仅用于提升境内地点检索精度；天地图 tk 启用天地图瓦片源。不填写时使用免密钥的 Nominatim 检索，离线地图包不受影响。'**
  String get keysFoot;

  /// No description provided for @secCategories.
  ///
  /// In zh, this message translates to:
  /// **'地点分类'**
  String get secCategories;

  /// No description provided for @secDanger.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get secDanger;

  /// No description provided for @clearAllTitle.
  ///
  /// In zh, this message translates to:
  /// **'一键清空我的攻略'**
  String get clearAllTitle;

  /// No description provided for @clearAllSub.
  ///
  /// In zh, this message translates to:
  /// **'删除全部攻略（含标记 / 照片 / 游览区域）与对应图片文件，不可恢复；重启应用会自动恢复演示攻略'**
  String get clearAllSub;

  /// No description provided for @clearAllDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空全部攻略？'**
  String get clearAllDialogTitle;

  /// No description provided for @clearAllDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'将删除当前全部攻略（含标记 / 照片 / 游览区域）及其在应用数据目录中的图片文件，此操作不可恢复。\n\n若要保留某篇攻略，请先在攻略内用「生成分享文件」留档。'**
  String get clearAllDialogContent;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清空'**
  String get confirmClear;

  /// No description provided for @clearedToast.
  ///
  /// In zh, this message translates to:
  /// **'已清空 {n} 篇攻略（图片文件同步删除）'**
  String clearedToast(int n);

  /// No description provided for @secAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get secAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {v}'**
  String aboutVersion(String v);

  /// No description provided for @aboutLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'本作全部数据仅保存在本机，无云服务'**
  String get aboutLocalOnly;

  /// No description provided for @aboutMapSources.
  ///
  /// In zh, this message translates to:
  /// **'底图来源：高德 / 天地图 / OSM / Esri'**
  String get aboutMapSources;

  /// No description provided for @aboutMapSourcesSub.
  ///
  /// In zh, this message translates to:
  /// **'瓦片仅供个人离线使用，界面保留来源标示'**
  String get aboutMapSourcesSub;

  /// No description provided for @secLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get secLanguage;

  /// No description provided for @langSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get langSystem;

  /// No description provided for @langChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get langChinese;

  /// No description provided for @langEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @languageHint.
  ///
  /// In zh, this message translates to:
  /// **'切换即时生效，默认中文。'**
  String get languageHint;

  /// No description provided for @homeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'检索标题/简介'**
  String get homeSearchHint;

  /// No description provided for @tooltipSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get tooltipSearch;

  /// No description provided for @tooltipCloseSearch.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get tooltipCloseSearch;

  /// No description provided for @tooltipMenu.
  ///
  /// In zh, this message translates to:
  /// **'功能菜单'**
  String get tooltipMenu;

  /// No description provided for @fabNew.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get fabNew;

  /// No description provided for @menuDirLabel.
  ///
  /// In zh, this message translates to:
  /// **'数据目录：{dir}'**
  String menuDirLabel(String dir);

  /// No description provided for @dirUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get dirUnavailable;

  /// No description provided for @menuToggleListView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get menuToggleListView;

  /// No description provided for @menuToggleGridView.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get menuToggleGridView;

  /// No description provided for @menuGallery.
  ///
  /// In zh, this message translates to:
  /// **'地理相册'**
  String get menuGallery;

  /// No description provided for @menuOfflineMap.
  ///
  /// In zh, this message translates to:
  /// **'离线地图'**
  String get menuOfflineMap;

  /// No description provided for @menuLoadShare.
  ///
  /// In zh, this message translates to:
  /// **'加载分享'**
  String get menuLoadShare;

  /// No description provided for @menuSettings.
  ///
  /// In zh, this message translates to:
  /// **'系统设置'**
  String get menuSettings;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'攻略本是空的'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'下面没有任何攻略。\n点击右下角「新增」，把想去的地方标在地图上。'**
  String get homeEmptyHint;

  /// No description provided for @homeNoResult.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配「{query}」的攻略记录'**
  String homeNoResult(String query);

  /// No description provided for @mustVisitBadge.
  ///
  /// In zh, this message translates to:
  /// **'{n} 必去'**
  String mustVisitBadge(int n);

  /// No description provided for @placesUnit.
  ///
  /// In zh, this message translates to:
  /// **'{n} 地点'**
  String placesUnit(int n);

  /// No description provided for @sharedSuffix.
  ///
  /// In zh, this message translates to:
  /// **'（分享）'**
  String get sharedSuffix;

  /// No description provided for @noSummaryParen.
  ///
  /// In zh, this message translates to:
  /// **'（暂无简介）'**
  String get noSummaryParen;

  /// No description provided for @regionDomestic.
  ///
  /// In zh, this message translates to:
  /// **'境内'**
  String get regionDomestic;

  /// No description provided for @regionAbroad.
  ///
  /// In zh, this message translates to:
  /// **'境外'**
  String get regionAbroad;

  /// No description provided for @guideActionOpenMap.
  ///
  /// In zh, this message translates to:
  /// **'打开地图'**
  String get guideActionOpenMap;

  /// No description provided for @guideActionInfo.
  ///
  /// In zh, this message translates to:
  /// **'攻略信息'**
  String get guideActionInfo;

  /// No description provided for @guideActionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除攻略'**
  String get guideActionDelete;

  /// No description provided for @deleteGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除攻略？'**
  String get deleteGuideTitle;

  /// No description provided for @deleteGuideContent.
  ///
  /// In zh, this message translates to:
  /// **'「{title}」及其本地图文记录将从攻略本移除。'**
  String deleteGuideContent(String title);

  /// No description provided for @btnDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get btnDelete;

  /// No description provided for @deletedToast.
  ///
  /// In zh, this message translates to:
  /// **'已删除「{title}」（JSON 与本地图文已清理）'**
  String deletedToast(String title);

  /// No description provided for @importedToast.
  ///
  /// In zh, this message translates to:
  /// **'已导入「{name}」'**
  String importedToast(String name);

  /// No description provided for @importProgressTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入分享攻略'**
  String get importProgressTitle;

  /// No description provided for @importUnpacking.
  ///
  /// In zh, this message translates to:
  /// **'正在解包校验分享文件…'**
  String get importUnpacking;

  /// No description provided for @importAwaitingConfirm.
  ///
  /// In zh, this message translates to:
  /// **'检测到已导入过，等待确认…'**
  String get importAwaitingConfirm;

  /// No description provided for @importRemapping.
  ///
  /// In zh, this message translates to:
  /// **'正在重映射与落盘…'**
  String get importRemapping;

  /// No description provided for @importCancelling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消…'**
  String get importCancelling;

  /// No description provided for @btnImportAgain.
  ///
  /// In zh, this message translates to:
  /// **'再次导入'**
  String get btnImportAgain;

  /// No description provided for @importedBeforeTitle.
  ///
  /// In zh, this message translates to:
  /// **'已导入过该攻略'**
  String get importedBeforeTitle;

  /// No description provided for @importedBeforeContent.
  ///
  /// In zh, this message translates to:
  /// **'「{title}」已于此前导入过。\n再次导入将生成独立副本（不覆盖现有数据）。'**
  String importedBeforeContent(String title);

  /// No description provided for @importCancelled.
  ///
  /// In zh, this message translates to:
  /// **'导入已取消'**
  String get importCancelled;

  /// No description provided for @importInvalidFile.
  ///
  /// In zh, this message translates to:
  /// **'不是有效的分享文件'**
  String get importInvalidFile;

  /// No description provided for @importTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件超过 1GB，拒绝导入'**
  String get importTooLarge;

  /// No description provided for @importFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get importFailedTitle;

  /// No description provided for @importFailedPrefix.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：'**
  String get importFailedPrefix;

  /// No description provided for @btnOk.
  ///
  /// In zh, this message translates to:
  /// **'好的'**
  String get btnOk;

  /// No description provided for @shareFileTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'分享攻略文件'**
  String get shareFileTypeLabel;

  /// No description provided for @createStep1.
  ///
  /// In zh, this message translates to:
  /// **'攻略信息'**
  String get createStep1;

  /// No description provided for @createStep2.
  ///
  /// In zh, this message translates to:
  /// **'范围与区域'**
  String get createStep2;

  /// No description provided for @createTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'攻略标题，如：杭州两日游'**
  String get createTitleHint;

  /// No description provided for @createSummaryHint.
  ///
  /// In zh, this message translates to:
  /// **'简介（可选）'**
  String get createSummaryHint;

  /// No description provided for @createRegionTitle.
  ///
  /// In zh, this message translates to:
  /// **'攻略区域'**
  String get createRegionTitle;

  /// No description provided for @createCoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'封面图片'**
  String get createCoverTitle;

  /// No description provided for @createAddCover.
  ///
  /// In zh, this message translates to:
  /// **'添加封面图片'**
  String get createAddCover;

  /// No description provided for @createNoPhotoPick.
  ///
  /// In zh, this message translates to:
  /// **'当前平台暂不支持选图'**
  String get createNoPhotoPick;

  /// No description provided for @createNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步：选定范围'**
  String get createNext;

  /// No description provided for @createPrev.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get createPrev;

  /// No description provided for @createSkipStart.
  ///
  /// In zh, this message translates to:
  /// **'跳过，使用在线地图直接开始'**
  String get createSkipStart;

  /// No description provided for @createBanner.
  ///
  /// In zh, this message translates to:
  /// **'本攻略属于「{where}」，默认地图：{source}'**
  String createBanner(String where, String source);

  /// No description provided for @createWhereChina.
  ///
  /// In zh, this message translates to:
  /// **'中国境内'**
  String get createWhereChina;

  /// No description provided for @createWhereAbroad.
  ///
  /// In zh, this message translates to:
  /// **'中国境外'**
  String get createWhereAbroad;

  /// No description provided for @createSourceAmap.
  ///
  /// In zh, this message translates to:
  /// **'高德矢量'**
  String get createSourceAmap;

  /// No description provided for @createSourceOsm.
  ///
  /// In zh, this message translates to:
  /// **'OpenStreetMap'**
  String get createSourceOsm;

  /// No description provided for @regionTileChina.
  ///
  /// In zh, this message translates to:
  /// **'中国境内'**
  String get regionTileChina;

  /// No description provided for @regionTileOverseas.
  ///
  /// In zh, this message translates to:
  /// **'中国境外'**
  String get regionTileOverseas;

  /// No description provided for @regionTileChinaDesc.
  ///
  /// In zh, this message translates to:
  /// **'默认高德地图（GCJ-02 自动换算）'**
  String get regionTileChinaDesc;

  /// No description provided for @regionTileOverseasDesc.
  ///
  /// In zh, this message translates to:
  /// **'默认 OpenStreetMap（WGS-84）'**
  String get regionTileOverseasDesc;

  /// No description provided for @createSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'检索城市或地点，如：杭州 / 西湖 / 东京'**
  String get createSearchHint;

  /// No description provided for @createScopeFoot.
  ///
  /// In zh, this message translates to:
  /// **'已下载的地图包可离线使用；地图页可随时切换在线地图源。选定的城市将作为攻略范围。'**
  String get createScopeFoot;

  /// No description provided for @createHotTitle.
  ///
  /// In zh, this message translates to:
  /// **'试试这些热门城市（联网检索）'**
  String get createHotTitle;

  /// No description provided for @createHotFoot.
  ///
  /// In zh, this message translates to:
  /// **'也可以直接「跳过」——稍后在地图上手动缩放定位。检索结果来自 Nominatim（OpenStreetMap），设置页可配置高德 Key 后境内检索将优先使用高德。'**
  String get createHotFoot;

  /// No description provided for @createSearchError.
  ///
  /// In zh, this message translates to:
  /// **'检索失败：请检查网络连接（境内可在设置页配置高德 Key 提升精度）'**
  String get createSearchError;

  /// No description provided for @createNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配地点，换个关键词试试'**
  String get createNoMatch;

  /// No description provided for @createBtnUseLocal.
  ///
  /// In zh, this message translates to:
  /// **'使用本地地图'**
  String get createBtnUseLocal;

  /// No description provided for @createBtnUse.
  ///
  /// In zh, this message translates to:
  /// **'使用'**
  String get createBtnUse;

  /// No description provided for @createBtnDownload.
  ///
  /// In zh, this message translates to:
  /// **'一键下载'**
  String get createBtnDownload;

  /// No description provided for @createPackReady.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」已下载，可免流量使用'**
  String createPackReady(String name);

  /// No description provided for @createDemoDone.
  ///
  /// In zh, this message translates to:
  /// **'演示下载完成'**
  String get createDemoDone;

  /// No description provided for @createNoPack.
  ///
  /// In zh, this message translates to:
  /// **'本区域暂无离线地图包，可使用在线地图'**
  String get createNoPack;

  /// No description provided for @createPackFallbackName.
  ///
  /// In zh, this message translates to:
  /// **'离线地图包'**
  String get createPackFallbackName;

  /// No description provided for @legendTitle.
  ///
  /// In zh, this message translates to:
  /// **'图例'**
  String get legendTitle;

  /// No description provided for @legendZoneNumbered.
  ///
  /// In zh, this message translates to:
  /// **'游览区域 {n}'**
  String legendZoneNumbered(int n);

  /// No description provided for @legendZoneNamed.
  ///
  /// In zh, this message translates to:
  /// **'游览区域 {n}（{name}）'**
  String legendZoneNamed(int n, String name);

  /// No description provided for @legendZonePoints.
  ///
  /// In zh, this message translates to:
  /// **'{n} 点'**
  String legendZonePoints(int n);

  /// No description provided for @catNameScenic.
  ///
  /// In zh, this message translates to:
  /// **'景点'**
  String get catNameScenic;

  /// No description provided for @catNameDining.
  ///
  /// In zh, this message translates to:
  /// **'餐饮'**
  String get catNameDining;

  /// No description provided for @catNameHotel.
  ///
  /// In zh, this message translates to:
  /// **'住宿'**
  String get catNameHotel;

  /// No description provided for @catNameShopping.
  ///
  /// In zh, this message translates to:
  /// **'购物'**
  String get catNameShopping;

  /// No description provided for @catNameTransport.
  ///
  /// In zh, this message translates to:
  /// **'交通'**
  String get catNameTransport;

  /// No description provided for @catNameOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get catNameOther;

  /// No description provided for @srcAmapVector.
  ///
  /// In zh, this message translates to:
  /// **'高德矢量'**
  String get srcAmapVector;

  /// No description provided for @srcAmapSatellite.
  ///
  /// In zh, this message translates to:
  /// **'高德卫星'**
  String get srcAmapSatellite;

  /// No description provided for @srcOsm.
  ///
  /// In zh, this message translates to:
  /// **'OpenStreetMap'**
  String get srcOsm;

  /// No description provided for @srcEsriStreet.
  ///
  /// In zh, this message translates to:
  /// **'Esri 街道（免 Key）'**
  String get srcEsriStreet;

  /// No description provided for @srcEsriTopo.
  ///
  /// In zh, this message translates to:
  /// **'Esri 地形（免 Key）'**
  String get srcEsriTopo;

  /// No description provided for @srcEsriGray.
  ///
  /// In zh, this message translates to:
  /// **'Esri 浅灰（免 Key）'**
  String get srcEsriGray;

  /// No description provided for @srcEsriSatellite.
  ///
  /// In zh, this message translates to:
  /// **'Esri 卫星'**
  String get srcEsriSatellite;

  /// No description provided for @srcTianditu.
  ///
  /// In zh, this message translates to:
  /// **'天地图'**
  String get srcTianditu;

  /// No description provided for @srcKindVector.
  ///
  /// In zh, this message translates to:
  /// **'矢量底图'**
  String get srcKindVector;

  /// No description provided for @srcKindSatellite.
  ///
  /// In zh, this message translates to:
  /// **'卫星影像'**
  String get srcKindSatellite;

  /// No description provided for @srcTdtKeySuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 需在设置页填入天地图 tk'**
  String get srcTdtKeySuffix;

  /// No description provided for @mapTooltipLayers.
  ///
  /// In zh, this message translates to:
  /// **'图层与照片'**
  String get mapTooltipLayers;

  /// No description provided for @mapTooltipSource.
  ///
  /// In zh, this message translates to:
  /// **'地图源'**
  String get mapTooltipSource;

  /// No description provided for @mapTooltipMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get mapTooltipMore;

  /// No description provided for @mapMenuNotes.
  ///
  /// In zh, this message translates to:
  /// **'攻略笔记'**
  String get mapMenuNotes;

  /// No description provided for @mapMenuZoneParams.
  ///
  /// In zh, this message translates to:
  /// **'重设参数'**
  String get mapMenuZoneParams;

  /// No description provided for @mapMenuShare.
  ///
  /// In zh, this message translates to:
  /// **'生成分享'**
  String get mapMenuShare;

  /// No description provided for @mapFabLocate.
  ///
  /// In zh, this message translates to:
  /// **'定位与照片一并接入'**
  String get mapFabLocate;

  /// No description provided for @mapHintPill.
  ///
  /// In zh, this message translates to:
  /// **'点按 Pin 查看详情 · 长按地图添加标记'**
  String get mapHintPill;

  /// No description provided for @mapFabMarkers.
  ///
  /// In zh, this message translates to:
  /// **'标记'**
  String get mapFabMarkers;

  /// No description provided for @layersTitle.
  ///
  /// In zh, this message translates to:
  /// **'地图图层'**
  String get layersTitle;

  /// No description provided for @layerMarkers.
  ///
  /// In zh, this message translates to:
  /// **'地点标记'**
  String get layerMarkers;

  /// No description provided for @layerMarkersSub.
  ///
  /// In zh, this message translates to:
  /// **'各分类色彩 Pin 图标'**
  String get layerMarkersSub;

  /// No description provided for @layerZoneCircles.
  ///
  /// In zh, this message translates to:
  /// **'游览区域范围圈'**
  String get layerZoneCircles;

  /// No description provided for @layerZoneCirclesSub.
  ///
  /// In zh, this message translates to:
  /// **'必去点聚类色带（参数见 ⋮ 菜单重设）'**
  String get layerZoneCirclesSub;

  /// No description provided for @layerPhotosTitle.
  ///
  /// In zh, this message translates to:
  /// **'地理相册 · 照片层'**
  String get layerPhotosTitle;

  /// No description provided for @layerPhotosSub.
  ///
  /// In zh, this message translates to:
  /// **'GPS 照片/视频叠上攻略地图；关闭即纯攻略地图（地理相册页反向同理）'**
  String get layerPhotosSub;

  /// No description provided for @recalcTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新计算游览区域'**
  String get recalcTitle;

  /// No description provided for @recalcSub.
  ///
  /// In zh, this message translates to:
  /// **'半径/必去变化后会自动重算；此处手动强刷'**
  String get recalcSub;

  /// No description provided for @snackRecalcRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在重算游览区域…'**
  String get snackRecalcRunning;

  /// No description provided for @zoneDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'重设游览区域参数'**
  String get zoneDialogTitle;

  /// No description provided for @zoneRadiusDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'游览区域半径'**
  String get zoneRadiusDialogTitle;

  /// No description provided for @zoneDialogFoot.
  ///
  /// In zh, this message translates to:
  /// **'半径 = 圆心到圈边的距离（1 km 半径的圈宽约 2 km），非直径；DBSCAN 以它判定必去点是否聚成同一游览区域。'**
  String get zoneDialogFoot;

  /// No description provided for @zoneDialogFollowState.
  ///
  /// In zh, this message translates to:
  /// **'本攻略当前跟随通用设置；重设后仅对本攻略生效。'**
  String get zoneDialogFollowState;

  /// No description provided for @zoneDialogOverridden.
  ///
  /// In zh, this message translates to:
  /// **'本攻略已重设，可点击「恢复通用设置」还原。'**
  String get zoneDialogOverridden;

  /// No description provided for @snackZoneRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复跟随通用设置，游览区域重算中…'**
  String get snackZoneRestored;

  /// No description provided for @btnRestoreGlobal.
  ///
  /// In zh, this message translates to:
  /// **'恢复通用设置'**
  String get btnRestoreGlobal;

  /// No description provided for @btnApplyRecalc.
  ///
  /// In zh, this message translates to:
  /// **'应用并重算'**
  String get btnApplyRecalc;

  /// No description provided for @snackZoneApplied.
  ///
  /// In zh, this message translates to:
  /// **'游览区域已按新参数重算（仅本攻略生效）'**
  String get snackZoneApplied;

  /// No description provided for @srcSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择地图源'**
  String get srcSheetTitle;

  /// No description provided for @srcSheetIntro.
  ///
  /// In zh, this message translates to:
  /// **'境内攻略默认高德（GCJ-02 自动换算），境外默认 OpenStreetMap。下方列出已下载的离线瓦片包，勾选即用（无网络可用）。'**
  String get srcSheetIntro;

  /// No description provided for @srcTagChinaRec.
  ///
  /// In zh, this message translates to:
  /// **'境内推荐'**
  String get srcTagChinaRec;

  /// No description provided for @srcTagOverseasRec.
  ///
  /// In zh, this message translates to:
  /// **'境外推荐'**
  String get srcTagOverseasRec;

  /// No description provided for @srcTagWebNoDownload.
  ///
  /// In zh, this message translates to:
  /// **'Web 内不可下'**
  String get srcTagWebNoDownload;

  /// No description provided for @srcPacksNone.
  ///
  /// In zh, this message translates to:
  /// **'（暂无离线包——在「离线地图」页新建下载后这里会出现）'**
  String get srcPacksNone;

  /// No description provided for @offlinePrefix.
  ///
  /// In zh, this message translates to:
  /// **'[离线]'**
  String get offlinePrefix;

  /// No description provided for @tileCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张'**
  String tileCountUnit(int n);

  /// No description provided for @srcHintEsri.
  ///
  /// In zh, this message translates to:
  /// **' · 免密钥，浏览器可直抓'**
  String get srcHintEsri;

  /// No description provided for @srcHintOsm.
  ///
  /// In zh, this message translates to:
  /// **' · 境内直连常不可达，下载前先连线测试'**
  String get srcHintOsm;

  /// No description provided for @snackNeedsTdtKey.
  ///
  /// In zh, this message translates to:
  /// **'天地图需先在「设置 → 服务密钥」填入 tk'**
  String get snackNeedsTdtKey;

  /// No description provided for @snackPackSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已切换到离线包「{name}」'**
  String snackPackSwitched(String name);

  /// No description provided for @infoSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'攻略信息'**
  String get infoSheetTitle;

  /// No description provided for @infoSheetSub.
  ///
  /// In zh, this message translates to:
  /// **'标题、简介与封面可随时修改，首页卡片即时同步'**
  String get infoSheetSub;

  /// No description provided for @infoTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'攻略标题'**
  String get infoTitleHint;

  /// No description provided for @infoSummaryHint.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get infoSummaryHint;

  /// No description provided for @infoCoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'封面图片（可选）'**
  String get infoCoverTitle;

  /// No description provided for @infoChangeCover.
  ///
  /// In zh, this message translates to:
  /// **'更换'**
  String get infoChangeCover;

  /// No description provided for @infoRemoveCover.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get infoRemoveCover;

  /// No description provided for @infoAddCover.
  ///
  /// In zh, this message translates to:
  /// **'添加封面图片（不添加则使用色块封面）'**
  String get infoAddCover;

  /// No description provided for @infoSaved.
  ///
  /// In zh, this message translates to:
  /// **'攻略信息已更新（JSON 与封面已保存）'**
  String get infoSaved;

  /// No description provided for @btnSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get btnSave;

  /// No description provided for @editNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增地点'**
  String get editNewTitle;

  /// No description provided for @editEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑地点'**
  String get editEditTitle;

  /// No description provided for @editIconNotSaved.
  ///
  /// In zh, this message translates to:
  /// **'存储不可用，自定义图标未保存'**
  String get editIconNotSaved;

  /// No description provided for @editTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写地点名称'**
  String get editTitleRequired;

  /// No description provided for @markerAdded.
  ///
  /// In zh, this message translates to:
  /// **'标记已添加'**
  String get markerAdded;

  /// No description provided for @markerSaved.
  ///
  /// In zh, this message translates to:
  /// **'修改已保存'**
  String get markerSaved;

  /// No description provided for @groupIdentity.
  ///
  /// In zh, this message translates to:
  /// **'名称与分类'**
  String get groupIdentity;

  /// No description provided for @editTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'地点名称，如：西湖 · 断桥'**
  String get editTitleHint;

  /// No description provided for @groupPinStyle.
  ///
  /// In zh, this message translates to:
  /// **'Pin 样式'**
  String get groupPinStyle;

  /// No description provided for @pinUploadCustom.
  ///
  /// In zh, this message translates to:
  /// **'上传自定义 Pin 图'**
  String get pinUploadCustom;

  /// No description provided for @pinChangeIcon.
  ///
  /// In zh, this message translates to:
  /// **'更换 Pin 图'**
  String get pinChangeIcon;

  /// No description provided for @pinResetIcon.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认图标'**
  String get pinResetIcon;

  /// No description provided for @groupRules.
  ///
  /// In zh, this message translates to:
  /// **'出行规则'**
  String get groupRules;

  /// No description provided for @mustSwitchTitle.
  ///
  /// In zh, this message translates to:
  /// **'必去地点'**
  String get mustSwitchTitle;

  /// No description provided for @mustSwitchSub.
  ///
  /// In zh, this message translates to:
  /// **'勾选「必去」将参与游览区域聚类与最佳推荐路径；「选去」仅作为备选展示'**
  String get mustSwitchSub;

  /// No description provided for @gpsCoordTitle.
  ///
  /// In zh, this message translates to:
  /// **'GPS 坐标（WGS-84）'**
  String get gpsCoordTitle;

  /// No description provided for @latNorth.
  ///
  /// In zh, this message translates to:
  /// **'北纬'**
  String get latNorth;

  /// No description provided for @latSouth.
  ///
  /// In zh, this message translates to:
  /// **'南纬'**
  String get latSouth;

  /// No description provided for @lngEast.
  ///
  /// In zh, this message translates to:
  /// **'东经'**
  String get lngEast;

  /// No description provided for @lngWest.
  ///
  /// In zh, this message translates to:
  /// **'西经'**
  String get lngWest;

  /// No description provided for @copyCoords.
  ///
  /// In zh, this message translates to:
  /// **'复制坐标'**
  String get copyCoords;

  /// No description provided for @coordsCopied.
  ///
  /// In zh, this message translates to:
  /// **'坐标已复制'**
  String get coordsCopied;

  /// No description provided for @repickOnMap.
  ///
  /// In zh, this message translates to:
  /// **'重新在地图上点选'**
  String get repickOnMap;

  /// No description provided for @verifyNav.
  ///
  /// In zh, this message translates to:
  /// **'验证导航'**
  String get verifyNav;

  /// No description provided for @groupDetails.
  ///
  /// In zh, this message translates to:
  /// **'图文详情'**
  String get groupDetails;

  /// No description provided for @editDescHint.
  ///
  /// In zh, this message translates to:
  /// **'记录开放时间、口味推荐、避坑小贴士……'**
  String get editDescHint;

  /// No description provided for @groupPhotos.
  ///
  /// In zh, this message translates to:
  /// **'位置照片'**
  String get groupPhotos;

  /// No description provided for @addPhoto.
  ///
  /// In zh, this message translates to:
  /// **'添加照片'**
  String get addPhoto;

  /// No description provided for @groupLinks.
  ///
  /// In zh, this message translates to:
  /// **'相关链接'**
  String get groupLinks;

  /// No description provided for @linkInvalid.
  ///
  /// In zh, this message translates to:
  /// **'该链接无效'**
  String get linkInvalid;

  /// No description provided for @addLink.
  ///
  /// In zh, this message translates to:
  /// **'添加链接'**
  String get addLink;

  /// No description provided for @noLinks.
  ///
  /// In zh, this message translates to:
  /// **'未添加链接'**
  String get noLinks;

  /// No description provided for @linkDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加链接'**
  String get linkDialogTitle;

  /// No description provided for @linkNameHint.
  ///
  /// In zh, this message translates to:
  /// **'链接名称，如：官方订票'**
  String get linkNameHint;

  /// No description provided for @linkDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get linkDefaultName;

  /// No description provided for @urlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写 URL'**
  String get urlRequired;

  /// No description provided for @btnAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get btnAdd;

  /// No description provided for @mustVisitTag.
  ///
  /// In zh, this message translates to:
  /// **'必去'**
  String get mustVisitTag;

  /// No description provided for @optionalTag.
  ///
  /// In zh, this message translates to:
  /// **'选去'**
  String get optionalTag;

  /// No description provided for @photosSection.
  ///
  /// In zh, this message translates to:
  /// **'位置照片（{n}）'**
  String photosSection(int n);

  /// No description provided for @noPhotosHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无照片——点「编辑详情」添加图文。'**
  String get noPhotosHint;

  /// No description provided for @navHere.
  ///
  /// In zh, this message translates to:
  /// **'导航到这里'**
  String get navHere;

  /// No description provided for @editDetails.
  ///
  /// In zh, this message translates to:
  /// **'编辑详情'**
  String get editDetails;

  /// No description provided for @deleteMarkerTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除标记？'**
  String get deleteMarkerTitle;

  /// No description provided for @deleteMarkerContent.
  ///
  /// In zh, this message translates to:
  /// **'「{title}」及其图文记录将被移除。'**
  String deleteMarkerContent(String title);

  /// No description provided for @markerDeletedToast.
  ///
  /// In zh, this message translates to:
  /// **'已删除「{title}」'**
  String markerDeletedToast(String title);

  /// No description provided for @drawerTitle.
  ///
  /// In zh, this message translates to:
  /// **'标记列表（{n}）'**
  String drawerTitle(int n);

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @sortCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get sortCategory;

  /// No description provided for @sortZone.
  ///
  /// In zh, this message translates to:
  /// **'游览区域'**
  String get sortZone;

  /// No description provided for @sortTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get sortTime;

  /// No description provided for @drawerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的标记'**
  String get drawerEmpty;

  /// No description provided for @imageCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 图'**
  String imageCount(int n);

  /// No description provided for @pickPointTitle.
  ///
  /// In zh, this message translates to:
  /// **'在地图上重新选点'**
  String get pickPointTitle;

  /// No description provided for @pickConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定这个位置'**
  String get pickConfirm;

  /// No description provided for @navAmapFail.
  ///
  /// In zh, this message translates to:
  /// **'未能打开地图，坐标已复制到剪贴板'**
  String get navAmapFail;

  /// No description provided for @navUrlFail.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接（浏览器/平台限制）'**
  String get navUrlFail;

  /// No description provided for @tilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'离线地图'**
  String get tilesTitle;

  /// No description provided for @fabNewPack.
  ///
  /// In zh, this message translates to:
  /// **'新建下载包'**
  String get fabNewPack;

  /// No description provided for @deletePackTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除离线包？'**
  String get deletePackTitle;

  /// No description provided for @deletePackContent.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」的 {n} 张瓦片文件将被删除并释放空间，对应的攻略底图将不再命中。'**
  String deletePackContent(String name, int n);

  /// No description provided for @packDeletedToast.
  ///
  /// In zh, this message translates to:
  /// **'已删除「{name}」，空间已释放'**
  String packDeletedToast(String name);

  /// No description provided for @tilesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有离线包'**
  String get tilesEmptyTitle;

  /// No description provided for @tilesEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'右下角「新建下载包」框选区域与级数即可下载'**
  String get tilesEmptyHint;

  /// No description provided for @bannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地瓦片包'**
  String get bannerTitle;

  /// No description provided for @bannerSub.
  ///
  /// In zh, this message translates to:
  /// **'框选范围与缩放级别下载后，无网络也可打开该区域地图；删除即释放空间。'**
  String get bannerSub;

  /// No description provided for @tilesFoot.
  ///
  /// In zh, this message translates to:
  /// **'桌面端：境内建议高德源（细节好，GCJ-02 框选自动换算），境外 OSM / Esri；浏览器端：首选 Esri 系列（免 Key，高德被 CORS 拦、OSM 境内常不可达）。缩放每 +1 瓦片约 ×4 倍，大范围高级别请谨慎；下载前可用「连线测试」验证可达性。'**
  String get tilesFoot;

  /// No description provided for @dateMthDy.
  ///
  /// In zh, this message translates to:
  /// **'{m}月{d}日'**
  String dateMthDy(String m, String d);

  /// No description provided for @completedOn.
  ///
  /// In zh, this message translates to:
  /// **'完成于 {date}'**
  String completedOn(String date);

  /// No description provided for @menuRefill.
  ///
  /// In zh, this message translates to:
  /// **'重新下载缺片'**
  String get menuRefill;

  /// No description provided for @snackRefillUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'增量补载会在 M6 后按需开放'**
  String get snackRefillUnavailable;

  /// No description provided for @wizardTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建离线瓦片包'**
  String get wizardTitle;

  /// No description provided for @stepChooseSource.
  ///
  /// In zh, this message translates to:
  /// **'选择地图源'**
  String get stepChooseSource;

  /// No description provided for @stepSelectArea.
  ///
  /// In zh, this message translates to:
  /// **'框选下载范围'**
  String get stepSelectArea;

  /// No description provided for @stepChooseZoom.
  ///
  /// In zh, this message translates to:
  /// **'选择缩放级别'**
  String get stepChooseZoom;

  /// No description provided for @stepConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认并下载'**
  String get stepConfirm;

  /// No description provided for @wizardNeedRange.
  ///
  /// In zh, this message translates to:
  /// **'请先在地图上点选两个对角点划定范围'**
  String get wizardNeedRange;

  /// No description provided for @rangeTooSmall.
  ///
  /// In zh, this message translates to:
  /// **'范围过小或级别过低，请调整范围/级数'**
  String get rangeTooSmall;

  /// No description provided for @hugeConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'范围较大，确认下载？'**
  String get hugeConfirmTitle;

  /// No description provided for @hugeConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 张瓦片（约 {mb} MB~更高）。耗时取决于网络，可随时取消，已下载部分保留可用。'**
  String hugeConfirmContent(int n, String mb);

  /// No description provided for @btnRethink.
  ///
  /// In zh, this message translates to:
  /// **'再想想'**
  String get btnRethink;

  /// No description provided for @btnContinueDownload.
  ///
  /// In zh, this message translates to:
  /// **'继续下载'**
  String get btnContinueDownload;

  /// No description provided for @progressInit.
  ///
  /// In zh, this message translates to:
  /// **'0 / {n} · 并发 4 · 重试 2'**
  String progressInit(int n);

  /// No description provided for @progressText.
  ///
  /// In zh, this message translates to:
  /// **'{done} / {total} · {mb} MB（已下载保留，可续传）'**
  String progressText(int done, int total, String mb);

  /// No description provided for @cancelReasonWebCgj.
  ///
  /// In zh, this message translates to:
  /// **'浏览器内被高德源跨域（CORS）拦截：改用 Esri 源，或用 Windows 桌面端下载高德源'**
  String get cancelReasonWebCgj;

  /// No description provided for @cancelReasonWeb.
  ///
  /// In zh, this message translates to:
  /// **'浏览器内请求被目标站点跨域（CORS）拦截或断网，可换 OSM 源试试'**
  String get cancelReasonWeb;

  /// No description provided for @cancelReasonOffline.
  ///
  /// In zh, this message translates to:
  /// **'连续请求全部失败（可能是断网/地址拒访），请检查网络后重试'**
  String get cancelReasonOffline;

  /// No description provided for @cancelledKept.
  ///
  /// In zh, this message translates to:
  /// **'已取消（已落盘部分保留）'**
  String get cancelledKept;

  /// No description provided for @reportStats.
  ///
  /// In zh, this message translates to:
  /// **'{reason}：成功 {ok} · 跳过 {skip} · 失败 {fail}'**
  String reportStats(String reason, int ok, int skip, int fail);

  /// No description provided for @snackAbortedKept.
  ///
  /// In zh, this message translates to:
  /// **'已中断，已落盘部分保留可续传（未写清单）'**
  String get snackAbortedKept;

  /// No description provided for @downloadedNoneMsg.
  ///
  /// In zh, this message translates to:
  /// **'未下载到任何瓦片：{n} 片失败，请检查网络'**
  String downloadedNoneMsg(int n);

  /// No description provided for @snackNoneDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'未下载到任何瓦片，请检查网络后重试'**
  String get snackNoneDownloaded;

  /// No description provided for @manifestFail.
  ///
  /// In zh, this message translates to:
  /// **'清单写入失败（存储配额？），瓦片已保留'**
  String get manifestFail;

  /// No description provided for @doneLabel.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get doneLabel;

  /// No description provided for @donePartial.
  ///
  /// In zh, this message translates to:
  /// **'完成（含失败片）'**
  String get donePartial;

  /// No description provided for @doneMsgLine.
  ///
  /// In zh, this message translates to:
  /// **'{what}：{report} · {secs} 秒'**
  String doneMsgLine(String what, String report, int secs);

  /// No description provided for @snackPackReady.
  ///
  /// In zh, this message translates to:
  /// **'离线包已就绪（{n} 张），可在攻略地图源中勾选使用'**
  String snackPackReady(int n);

  /// No description provided for @snackPartialFail.
  ///
  /// In zh, this message translates to:
  /// **'部分瓦片失败（{n}），可重新下载续传'**
  String snackPartialFail(int n);

  /// No description provided for @packNameUnnamed.
  ///
  /// In zh, this message translates to:
  /// **'未命名地图包'**
  String get packNameUnnamed;

  /// No description provided for @needRangeForProbe.
  ///
  /// In zh, this message translates to:
  /// **'请先在框选步骤选定范围'**
  String get needRangeForProbe;

  /// No description provided for @probing.
  ///
  /// In zh, this message translates to:
  /// **'正在连线测试（取 1 片实测）…'**
  String get probing;

  /// No description provided for @extraWebCgj.
  ///
  /// In zh, this message translates to:
  /// **'（浏览器版本中高德源会被 CORS 拦截）'**
  String get extraWebCgj;

  /// No description provided for @probeOk.
  ///
  /// In zh, this message translates to:
  /// **'✅ 连线正常：HTTP {status} · {ms} 毫秒 {extra}'**
  String probeOk(String status, int ms, String extra);

  /// No description provided for @probeFailWeb.
  ///
  /// In zh, this message translates to:
  /// **'❌ 不通（HTTP {status} · {ms} 毫秒）—— 换 Esri/OSM 源试试，或用 Windows 桌面端'**
  String probeFailWeb(String status, int ms);

  /// No description provided for @probeFailDesktop.
  ///
  /// In zh, this message translates to:
  /// **'❌ 不通（HTTP {status} · {ms} 毫秒）—— 请检查网络'**
  String probeFailDesktop(String status, int ms);

  /// No description provided for @srcRecommendFoot.
  ///
  /// In zh, this message translates to:
  /// **'境内建议高德源（{note}），境外建议 OSM / Esri。'**
  String srcRecommendFoot(String note);

  /// No description provided for @srcNoteGcj.
  ///
  /// In zh, this message translates to:
  /// **'GCJ-02 框选点已自动换算'**
  String get srcNoteGcj;

  /// No description provided for @srcNoteWgs.
  ///
  /// In zh, this message translates to:
  /// **'WGS-84'**
  String get srcNoteWgs;

  /// No description provided for @webPreviewNote.
  ///
  /// In zh, this message translates to:
  /// **'浏览器预览：首选 Esri 系列（免 Key），高德源会被 CORS 拦截，OSM 官方源境内常不可达；不确定就先「连线测试」。'**
  String get webPreviewNote;

  /// No description provided for @areaDone.
  ///
  /// In zh, this message translates to:
  /// **'已选定对角两点'**
  String get areaDone;

  /// No description provided for @areaHint.
  ///
  /// In zh, this message translates to:
  /// **'在下方地图点选两个对角点'**
  String get areaHint;

  /// No description provided for @btnClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get btnClear;

  /// No description provided for @pointLabelA.
  ///
  /// In zh, this message translates to:
  /// **'A：{value}'**
  String pointLabelA(String value);

  /// No description provided for @pointLabelB.
  ///
  /// In zh, this message translates to:
  /// **'B：{value}'**
  String pointLabelB(String value);

  /// No description provided for @notPicked.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get notPicked;

  /// No description provided for @zoomFootStep.
  ///
  /// In zh, this message translates to:
  /// **'z12–16 适合市内街道浏览；级别每 +1 瓦片约 ×4，注意容量与下载时长。'**
  String get zoomFootStep;

  /// No description provided for @rowMapSource.
  ///
  /// In zh, this message translates to:
  /// **'地图源'**
  String get rowMapSource;

  /// No description provided for @rowCoordSys.
  ///
  /// In zh, this message translates to:
  /// **'坐标系'**
  String get rowCoordSys;

  /// No description provided for @coordRowGcj.
  ///
  /// In zh, this message translates to:
  /// **'GCJ-02（框选点已换算）'**
  String get coordRowGcj;

  /// No description provided for @rowRange.
  ///
  /// In zh, this message translates to:
  /// **'范围'**
  String get rowRange;

  /// No description provided for @rowZoom.
  ///
  /// In zh, this message translates to:
  /// **'缩放级别'**
  String get rowZoom;

  /// No description provided for @rowManifest.
  ///
  /// In zh, this message translates to:
  /// **'实际清单'**
  String get rowManifest;

  /// No description provided for @manifestValue.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张 · 约 {mb} MB'**
  String manifestValue(int n, String mb);

  /// No description provided for @manifestPending.
  ///
  /// In zh, this message translates to:
  /// **'请先完成范围选择'**
  String get manifestPending;

  /// No description provided for @probeBtnValue.
  ///
  /// In zh, this message translates to:
  /// **'连线测试（下载前实测 1 片可达性，几秒出结果）'**
  String get probeBtnValue;

  /// No description provided for @webCgjWarning.
  ///
  /// In zh, this message translates to:
  /// **'浏览器版本中高德源不支持跨域抓取（CORS），下载会失败。请改用 Esri 源，或用 Windows 桌面端下载高德源。'**
  String get webCgjWarning;

  /// No description provided for @startDownload.
  ///
  /// In zh, this message translates to:
  /// **'开始下载'**
  String get startDownload;

  /// No description provided for @cancelDownload.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get cancelDownload;

  /// No description provided for @btnNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get btnNext;

  /// No description provided for @videoDupPart.
  ///
  /// In zh, this message translates to:
  /// **' · 内容重复跳过 {n}'**
  String videoDupPart(int n);

  /// No description provided for @videoFailPart.
  ///
  /// In zh, this message translates to:
  /// **' · 处理失败 {n}（请重试或换格式）'**
  String videoFailPart(int n);

  /// No description provided for @videoFullPart.
  ///
  /// In zh, this message translates to:
  /// **' · 已达到相册取样上限'**
  String get videoFullPart;

  /// No description provided for @videoTailPart.
  ///
  /// In zh, this message translates to:
  /// **' —— 请点开视频（相册库）补写地理位置'**
  String get videoTailPart;

  /// No description provided for @videoInsertBanner.
  ///
  /// In zh, this message translates to:
  /// **'视频插入：新增 {imported}{dup}{fail}{full}{tail}'**
  String videoInsertBanner(
    int imported,
    String dup,
    String fail,
    String full,
    String tail,
  );

  /// No description provided for @removePhotoTitle.
  ///
  /// In zh, this message translates to:
  /// **'剔除照片'**
  String get removePhotoTitle;

  /// No description provided for @removeGuidePhotoContent.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」将从地理相册与攻略地图照片同时移除（重新导入才会恢复）。'**
  String removeGuidePhotoContent(String name);

  /// No description provided for @photoUnnamed.
  ///
  /// In zh, this message translates to:
  /// **'未命名照片'**
  String get photoUnnamed;

  /// No description provided for @removeLedgerPhotoContent.
  ///
  /// In zh, this message translates to:
  /// **'该照片将从地理相册与地图照片移除（重新加入才会恢复）。'**
  String get removeLedgerPhotoContent;

  /// No description provided for @removePhotoBtn.
  ///
  /// In zh, this message translates to:
  /// **'剔除'**
  String get removePhotoBtn;

  /// No description provided for @locateFailSnack.
  ///
  /// In zh, this message translates to:
  /// **'未能获取定位（浏览器需允许位置权限）'**
  String get locateFailSnack;

  /// No description provided for @scanFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量导入相册文件夹'**
  String get scanFolderTitle;

  /// No description provided for @scanFolderLabel.
  ///
  /// In zh, this message translates to:
  /// **'本地文件夹路径'**
  String get scanFolderLabel;

  /// No description provided for @scanFolderHint.
  ///
  /// In zh, this message translates to:
  /// **'C:\\Users\\你的用户名\\Pictures\\旅行照片'**
  String get scanFolderHint;

  /// No description provided for @startImport.
  ///
  /// In zh, this message translates to:
  /// **'开始导入'**
  String get startImport;

  /// No description provided for @batchImportStats.
  ///
  /// In zh, this message translates to:
  /// **'批量导入：新增 {imported} · 重复跳过 {duplicates}'**
  String batchImportStats(int imported, int duplicates);

  /// No description provided for @noGpsTail.
  ///
  /// In zh, this message translates to:
  /// **'，无定位 {n}'**
  String noGpsTail(int n);

  /// No description provided for @capReachedPart.
  ///
  /// In zh, this message translates to:
  /// **'（达到取样上限 {n}）'**
  String capReachedPart(int n);

  /// No description provided for @curateImportStats.
  ///
  /// In zh, this message translates to:
  /// **'精选加入：新增 {imported} · 重复跳过 {duplicates}'**
  String curateImportStats(int imported, int duplicates);

  /// No description provided for @insertVideosTitle.
  ///
  /// In zh, this message translates to:
  /// **'插入视频'**
  String get insertVideosTitle;

  /// No description provided for @insertVideosContent.
  ///
  /// In zh, this message translates to:
  /// **'视频从本机文件插入地理相册账本。\n插入手动定义地理位置：入册后需要在相册库中逐个为视频点选地图补写拍摄位置（视频无 EXIF 定位）。\n\n批量：一次多选窗口挑一批；逐个：一支一支选，随时取消。\n两种方式入册后效果相同。'**
  String get insertVideosContent;

  /// No description provided for @pickOneByOne.
  ///
  /// In zh, this message translates to:
  /// **'逐个挑选'**
  String get pickOneByOne;

  /// No description provided for @pickBatch.
  ///
  /// In zh, this message translates to:
  /// **'批量多选'**
  String get pickBatch;

  /// No description provided for @videoTypeGroup.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get videoTypeGroup;

  /// No description provided for @collectedOne.
  ///
  /// In zh, this message translates to:
  /// **'已收集 1 支视频'**
  String get collectedOne;

  /// No description provided for @pickNextAsk.
  ///
  /// In zh, this message translates to:
  /// **'继续挑下一支吗？'**
  String get pickNextAsk;

  /// No description provided for @startInsertNow.
  ///
  /// In zh, this message translates to:
  /// **'就这些，开始插入'**
  String get startInsertNow;

  /// No description provided for @keepPicking.
  ///
  /// In zh, this message translates to:
  /// **'继续挑选下一支'**
  String get keepPicking;

  /// No description provided for @pickVideoFail.
  ///
  /// In zh, this message translates to:
  /// **'选择视频失败：{err}'**
  String pickVideoFail(String err);

  /// No description provided for @removedToast.
  ///
  /// In zh, this message translates to:
  /// **'已剔除'**
  String get removedToast;

  /// No description provided for @geoWritten.
  ///
  /// In zh, this message translates to:
  /// **'已写入地理标识 {coords}'**
  String geoWritten(String coords);

  /// No description provided for @albumLibTooltip.
  ///
  /// In zh, this message translates to:
  /// **'相册库（全部照片 · GPS 状态 · 显示开关）'**
  String get albumLibTooltip;

  /// No description provided for @menuBatchImport.
  ///
  /// In zh, this message translates to:
  /// **'批量导入'**
  String get menuBatchImport;

  /// No description provided for @menuCurate.
  ///
  /// In zh, this message translates to:
  /// **'精选照片'**
  String get menuCurate;

  /// No description provided for @menuInsertVideos.
  ///
  /// In zh, this message translates to:
  /// **'插入视频'**
  String get menuInsertVideos;

  /// No description provided for @noticeEmpty.
  ///
  /// In zh, this message translates to:
  /// **'地理相册尚未加入照片——右上角 ⋮ 批量导入或精选加入'**
  String get noticeEmpty;

  /// No description provided for @noticeOnMap.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张已上图'**
  String noticeOnMap(int n);

  /// No description provided for @noticeMissing.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张无 GPS 暂不上图'**
  String noticeMissing(int n);

  /// No description provided for @noticeAllShown.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张照片已上图 · 放大地图查看更多'**
  String noticeAllShown(int n);

  /// No description provided for @baseMapAmap.
  ///
  /// In zh, this message translates to:
  /// **'底图 © 高德地图'**
  String get baseMapAmap;

  /// No description provided for @baseMapEsri.
  ///
  /// In zh, this message translates to:
  /// **'底图 © Esri（高德源不可达，已自动切换）'**
  String get baseMapEsri;

  /// No description provided for @baseMapOsm.
  ///
  /// In zh, this message translates to:
  /// **'底图 © OpenStreetMap（高德/Esri 均不可达）'**
  String get baseMapOsm;

  /// No description provided for @baseSwitchSnack.
  ///
  /// In zh, this message translates to:
  /// **'高德底图不可达，已切换：{name}'**
  String baseSwitchSnack(String name);

  /// No description provided for @albumLibTitle.
  ///
  /// In zh, this message translates to:
  /// **'相册库'**
  String get albumLibTitle;

  /// No description provided for @albumLibEmpty.
  ///
  /// In zh, this message translates to:
  /// **'相册库还是空的'**
  String get albumLibEmpty;

  /// No description provided for @albumLibEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'回到地理相册，用 ⋮ 菜单「批量导入 / 精选加入」添加'**
  String get albumLibEmptyHint;

  /// No description provided for @sourceAlbumImport.
  ///
  /// In zh, this message translates to:
  /// **'相册导入'**
  String get sourceAlbumImport;

  /// No description provided for @sourceGuide.
  ///
  /// In zh, this message translates to:
  /// **'攻略 · {title}'**
  String sourceGuide(String title);

  /// No description provided for @sourceGuidePhoto.
  ///
  /// In zh, this message translates to:
  /// **'攻略照片'**
  String get sourceGuidePhoto;

  /// No description provided for @geoUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新地理定位'**
  String get geoUpdated;

  /// No description provided for @currentGeoLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前定位 {coords}'**
  String currentGeoLabel(String coords);

  /// No description provided for @editGeoTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改地理定位'**
  String get editGeoTitle;

  /// No description provided for @editGeoHint.
  ///
  /// In zh, this message translates to:
  /// **'进入选点地图重新选择，确认后覆盖此条当前位置'**
  String get editGeoHint;

  /// No description provided for @videoRowTitle.
  ///
  /// In zh, this message translates to:
  /// **'视频{dur}'**
  String videoRowTitle(String dur);

  /// No description provided for @rowGps.
  ///
  /// In zh, this message translates to:
  /// **'GPS {coords}（长按行可修改定位）'**
  String rowGps(String coords);

  /// No description provided for @rowNoGeoVideo.
  ///
  /// In zh, this message translates to:
  /// **'无定位（点行进入查看器补写拍摄位置）'**
  String get rowNoGeoVideo;

  /// No description provided for @rowNoGps.
  ///
  /// In zh, this message translates to:
  /// **'无 GPS（查看照片时可补标识）'**
  String get rowNoGps;

  /// No description provided for @curateTitle.
  ///
  /// In zh, this message translates to:
  /// **'精选加入（勾选要入册的照片）'**
  String get curateTitle;

  /// No description provided for @curateAdd.
  ///
  /// In zh, this message translates to:
  /// **'加入 {n} 张'**
  String curateAdd(int n);

  /// No description provided for @viewPhotosTitle.
  ///
  /// In zh, this message translates to:
  /// **'浏览照片'**
  String get viewPhotosTitle;

  /// No description provided for @playWithDuration.
  ///
  /// In zh, this message translates to:
  /// **'播放 · {dur}'**
  String playWithDuration(String dur);

  /// No description provided for @playVideoBtn.
  ///
  /// In zh, this message translates to:
  /// **'播放视频'**
  String get playVideoBtn;

  /// No description provided for @geoTagTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置地理标识'**
  String get geoTagTitle;

  /// No description provided for @pickHint.
  ///
  /// In zh, this message translates to:
  /// **'缩放地图到合适区域后，点击目标位置落点'**
  String get pickHint;

  /// No description provided for @pickedHint.
  ///
  /// In zh, this message translates to:
  /// **'已落点（可继续点击微调位置）'**
  String get pickedHint;

  /// No description provided for @noLocationYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择位置'**
  String get noLocationYet;

  /// No description provided for @confirmLocation.
  ///
  /// In zh, this message translates to:
  /// **'确认该位置'**
  String get confirmLocation;

  /// No description provided for @removeThisPhoto.
  ///
  /// In zh, this message translates to:
  /// **'剔除该张'**
  String get removeThisPhoto;

  /// No description provided for @photoWallNoGuides.
  ///
  /// In zh, this message translates to:
  /// **'暂无攻略'**
  String get photoWallNoGuides;

  /// No description provided for @mapPhotosSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 地图照片'**
  String get mapPhotosSuffix;

  /// No description provided for @importParsing.
  ///
  /// In zh, this message translates to:
  /// **'正在解析 EXIF 与生成缩略图…（{n} 张）'**
  String importParsing(String n);

  /// No description provided for @importAllDup.
  ///
  /// In zh, this message translates to:
  /// **'所选择的都是重复照片（{n} 张），未重复导入'**
  String importAllDup(String n);

  /// No description provided for @importFail.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{err}'**
  String importFail(String err);

  /// No description provided for @switchGuideTip.
  ///
  /// In zh, this message translates to:
  /// **'切换攻略'**
  String get switchGuideTip;

  /// No description provided for @sortNewTip.
  ///
  /// In zh, this message translates to:
  /// **'拍摄时间：新→旧'**
  String get sortNewTip;

  /// No description provided for @sortOldTip.
  ///
  /// In zh, this message translates to:
  /// **'拍摄时间：旧→新'**
  String get sortOldTip;

  /// No description provided for @photoListTip.
  ///
  /// In zh, this message translates to:
  /// **'照片清单（已定位/未定位）'**
  String get photoListTip;

  /// No description provided for @importPhotosTip.
  ///
  /// In zh, this message translates to:
  /// **'导入照片'**
  String get importPhotosTip;

  /// No description provided for @layerPhotosOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅照片'**
  String get layerPhotosOnly;

  /// No description provided for @layerWithMarkers.
  ///
  /// In zh, this message translates to:
  /// **'+标记'**
  String get layerWithMarkers;

  /// No description provided for @markerOnPhotoMap.
  ///
  /// In zh, this message translates to:
  /// **'标记「{title}」— 在攻略地图页查看详情'**
  String markerOnPhotoMap(String title);

  /// No description provided for @photoListStats.
  ///
  /// In zh, this message translates to:
  /// **'照片 {total} 张 · 已定位 {located} · 未定位 {unlocated}'**
  String photoListStats(String total, String located, String unlocated);

  /// No description provided for @sectionUnlocated.
  ///
  /// In zh, this message translates to:
  /// **'未定位'**
  String get sectionUnlocated;

  /// No description provided for @boundPrefix.
  ///
  /// In zh, this message translates to:
  /// **'绑 {title} · '**
  String boundPrefix(String title);

  /// No description provided for @noLocBindTip.
  ///
  /// In zh, this message translates to:
  /// **'无定位（点击绑定标记）'**
  String get noLocBindTip;

  /// No description provided for @bindBtn.
  ///
  /// In zh, this message translates to:
  /// **'绑定'**
  String get bindBtn;

  /// No description provided for @renamePhotoTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名照片'**
  String get renamePhotoTitle;

  /// No description provided for @renamePhotoHint.
  ///
  /// In zh, this message translates to:
  /// **'如「日出 · 龙井茶园」（空则显示拍摄时间）'**
  String get renamePhotoHint;

  /// No description provided for @nameReset.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认名'**
  String get nameReset;

  /// No description provided for @renamedTo.
  ///
  /// In zh, this message translates to:
  /// **'已改名：{name}'**
  String renamedTo(String name);

  /// No description provided for @deletePhotoTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除照片'**
  String get deletePhotoTitle;

  /// No description provided for @deletePhotoContent.
  ///
  /// In zh, this message translates to:
  /// **'将从攻略删除该照片，并删除原图/缩略图文件。\n\n{title}'**
  String deletePhotoContent(String title);

  /// No description provided for @photoDeleted.
  ///
  /// In zh, this message translates to:
  /// **'照片已删除（文件已清理）'**
  String get photoDeleted;

  /// No description provided for @unboundToast.
  ///
  /// In zh, this message translates to:
  /// **'已解除绑定'**
  String get unboundToast;

  /// No description provided for @boundToast.
  ///
  /// In zh, this message translates to:
  /// **'已绑定：{name}'**
  String boundToast(String name);

  /// No description provided for @renameTip.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renameTip;

  /// No description provided for @latLngLine.
  ///
  /// In zh, this message translates to:
  /// **'北纬 {lat} · 东经 {lng}'**
  String latLngLine(String lat, String lng);

  /// No description provided for @noExifLine.
  ///
  /// In zh, this message translates to:
  /// **'无 EXIF 定位{tail}'**
  String noExifLine(String tail);

  /// No description provided for @exifFollowTail.
  ///
  /// In zh, this message translates to:
  /// **'（跟随绑定标记）'**
  String get exifFollowTail;

  /// No description provided for @changeBindBtn.
  ///
  /// In zh, this message translates to:
  /// **'更改绑定'**
  String get changeBindBtn;

  /// No description provided for @boundMarkerLine.
  ///
  /// In zh, this message translates to:
  /// **'绑定标记：{title}{tail}'**
  String boundMarkerLine(String title, String tail);

  /// No description provided for @shownAtMarkerTail.
  ///
  /// In zh, this message translates to:
  /// **'（显示在标记位置）'**
  String get shownAtMarkerTail;

  /// No description provided for @videoPlayTitle.
  ///
  /// In zh, this message translates to:
  /// **'视频播放'**
  String get videoPlayTitle;

  /// No description provided for @playerError.
  ///
  /// In zh, this message translates to:
  /// **'播放出错：{msg}'**
  String playerError(String msg);

  /// No description provided for @pathError.
  ///
  /// In zh, this message translates to:
  /// **'文件路径不可用：{msg}'**
  String pathError(String msg);

  /// No description provided for @btnBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get btnBack;

  /// No description provided for @bindToMarker.
  ///
  /// In zh, this message translates to:
  /// **'绑定到标记'**
  String get bindToMarker;

  /// No description provided for @changeBindTitle.
  ///
  /// In zh, this message translates to:
  /// **'更改绑定的标记'**
  String get changeBindTitle;

  /// No description provided for @bindNoMarkers.
  ///
  /// In zh, this message translates to:
  /// **'攻略还没有标记，先在地图页添加'**
  String get bindNoMarkers;

  /// No description provided for @distToShot.
  ///
  /// In zh, this message translates to:
  /// **'距拍摄点 {dist}'**
  String distToShot(String dist);

  /// No description provided for @unbindLine.
  ///
  /// In zh, this message translates to:
  /// **'解除绑定'**
  String get unbindLine;

  /// No description provided for @notesTitle.
  ///
  /// In zh, this message translates to:
  /// **'攻略笔记'**
  String get notesTitle;

  /// No description provided for @notesEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'攻略内尚无地点，先在地图上添加：长按地图新建标记'**
  String get notesEmptyHint;

  /// No description provided for @viewOnMapTip.
  ///
  /// In zh, this message translates to:
  /// **'在攻略地图中查看'**
  String get viewOnMapTip;

  /// No description provided for @zoneCountChip.
  ///
  /// In zh, this message translates to:
  /// **'{n} 游览区域'**
  String zoneCountChip(String n);

  /// No description provided for @scenicCountChip.
  ///
  /// In zh, this message translates to:
  /// **'{n} 游览点'**
  String scenicCountChip(String n);

  /// No description provided for @recommendedTail.
  ///
  /// In zh, this message translates to:
  /// **' · 推荐住宿'**
  String get recommendedTail;

  /// No description provided for @zoneLabelN.
  ///
  /// In zh, this message translates to:
  /// **'游览区域 {n}'**
  String zoneLabelN(String n);

  /// No description provided for @zoneRange.
  ///
  /// In zh, this message translates to:
  /// **'半径 {r} · 面积约 {a} k㎡'**
  String zoneRange(String r, String a);

  /// No description provided for @kmFromStart.
  ///
  /// In zh, this message translates to:
  /// **'距起点 {d} km'**
  String kmFromStart(String d);

  /// No description provided for @zoneEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本片区暂无登记地点'**
  String get zoneEmpty;

  /// No description provided for @secDiningRec.
  ///
  /// In zh, this message translates to:
  /// **'餐饮推荐'**
  String get secDiningRec;

  /// No description provided for @secShoppingRec.
  ///
  /// In zh, this message translates to:
  /// **'购物推荐'**
  String get secShoppingRec;

  /// No description provided for @secScenic.
  ///
  /// In zh, this message translates to:
  /// **'景点'**
  String get secScenic;

  /// No description provided for @secDining.
  ///
  /// In zh, this message translates to:
  /// **'餐饮'**
  String get secDining;

  /// No description provided for @secShopping.
  ///
  /// In zh, this message translates to:
  /// **'购物'**
  String get secShopping;

  /// No description provided for @secOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get secOther;

  /// No description provided for @photosTotalN.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 图'**
  String photosTotalN(String n);

  /// No description provided for @noPhotoYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无照片'**
  String get noPhotoYet;

  /// No description provided for @mustVisitStar.
  ///
  /// In zh, this message translates to:
  /// **'  ★必去'**
  String get mustVisitStar;

  /// No description provided for @descMissing.
  ///
  /// In zh, this message translates to:
  /// **'图文暂缺'**
  String get descMissing;

  /// No description provided for @navBtnShort.
  ///
  /// In zh, this message translates to:
  /// **'导航'**
  String get navBtnShort;

  /// No description provided for @stayHead.
  ///
  /// In zh, this message translates to:
  /// **'本次住宿 · 游览起点'**
  String get stayHead;

  /// No description provided for @stayPlan.
  ///
  /// In zh, this message translates to:
  /// **'从近到远安排各片区'**
  String get stayPlan;

  /// No description provided for @otherRecTitle.
  ///
  /// In zh, this message translates to:
  /// **'其他推荐（不在任何片区圈内）'**
  String get otherRecTitle;

  /// No description provided for @flatBanner.
  ///
  /// In zh, this message translates to:
  /// **'本攻略暂无必去点，未划分游览区域：以下为全部登记地点的类别平铺（住宿置顶）。在地图上把地点标为「必去」后，攻略笔记将自动按游览区域编排。'**
  String get flatBanner;

  /// No description provided for @preparing.
  ///
  /// In zh, this message translates to:
  /// **'准备…'**
  String get preparing;

  /// No description provided for @estMb.
  ///
  /// In zh, this message translates to:
  /// **'约 {n} MB'**
  String estMb(String n);

  /// No description provided for @estKb.
  ///
  /// In zh, this message translates to:
  /// **'约 {n} KB'**
  String estKb(String n);

  /// No description provided for @exportStats.
  ///
  /// In zh, this message translates to:
  /// **'标记 {m} · 照片 {ph} · 视频 {v} · 片区 {cl}'**
  String exportStats(String m, String ph, String v, String cl);

  /// No description provided for @estTotal.
  ///
  /// In zh, this message translates to:
  /// **'预计体积：{est}'**
  String estTotal(String est);

  /// No description provided for @includePhotosTitle.
  ///
  /// In zh, this message translates to:
  /// **'包含攻略照片（低质量副本 + 水印）'**
  String get includePhotosTitle;

  /// No description provided for @wmFromSettings.
  ///
  /// In zh, this message translates to:
  /// **'水印来自设置（可自定义）'**
  String get wmFromSettings;

  /// No description provided for @videoTransTail.
  ///
  /// In zh, this message translates to:
  /// **'；视频转 ≤720p 并烧录水印'**
  String get videoTransTail;

  /// No description provided for @noPhotosDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅导出标记 / 片区 / 文本，体积最小'**
  String get noPhotosDesc;

  /// No description provided for @receiverNote.
  ///
  /// In zh, this message translates to:
  /// **'接收方导入后可完整查看攻略；分享的照片与视频仅存于攻略内，不会进入其地理相册。'**
  String get receiverNote;

  /// No description provided for @genBtn.
  ///
  /// In zh, this message translates to:
  /// **'生成 .tgshare 文件'**
  String get genBtn;

  /// No description provided for @workingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在生成分享文件…'**
  String get workingTitle;

  /// No description provided for @progressLine.
  ///
  /// In zh, this message translates to:
  /// **'已处理 {d}/{n}：{label}'**
  String progressLine(String d, String n, String label);

  /// No description provided for @doneTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成完成'**
  String get doneTitle;

  /// No description provided for @doneNote.
  ///
  /// In zh, this message translates to:
  /// **'把该文件发给任何装有本应用的朋友，其「导入分享攻略」即可打开；也可留作您的永久备份。'**
  String get doneNote;

  /// No description provided for @btnFinish.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get btnFinish;

  /// No description provided for @failedTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get failedTitle;

  /// No description provided for @retryBtn.
  ///
  /// In zh, this message translates to:
  /// **'返回重试'**
  String get retryBtn;

  /// No description provided for @progStructured.
  ///
  /// In zh, this message translates to:
  /// **'结构化数据'**
  String get progStructured;

  /// No description provided for @progManifest.
  ///
  /// In zh, this message translates to:
  /// **'清单'**
  String get progManifest;

  /// No description provided for @progCover.
  ///
  /// In zh, this message translates to:
  /// **'封面'**
  String get progCover;

  /// No description provided for @progPhoto.
  ///
  /// In zh, this message translates to:
  /// **'照片 {name}'**
  String progPhoto(String name);

  /// No description provided for @progThumb.
  ///
  /// In zh, this message translates to:
  /// **'缩略 {name}'**
  String progThumb(String name);

  /// No description provided for @progImage.
  ///
  /// In zh, this message translates to:
  /// **'插图 {name}'**
  String progImage(String name);

  /// No description provided for @progTranscode.
  ///
  /// In zh, this message translates to:
  /// **'视频转码 {name}'**
  String progTranscode(String name);

  /// No description provided for @progVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频 {name}'**
  String progVideo(String name);

  /// No description provided for @progWriteCover.
  ///
  /// In zh, this message translates to:
  /// **'正在写入封面'**
  String get progWriteCover;

  /// No description provided for @progImportImage.
  ///
  /// In zh, this message translates to:
  /// **'正在传入插图：{name}'**
  String progImportImage(String name);

  /// No description provided for @progGenMap.
  ///
  /// In zh, this message translates to:
  /// **'正在生成地图：{name}'**
  String progGenMap(String name);

  /// No description provided for @progImportPhoto.
  ///
  /// In zh, this message translates to:
  /// **'正在传入照片：{name}'**
  String progImportPhoto(String name);

  /// No description provided for @progGenThumb.
  ///
  /// In zh, this message translates to:
  /// **'正在生成缩略：{name}'**
  String progGenThumb(String name);

  /// No description provided for @progImportVideo.
  ///
  /// In zh, this message translates to:
  /// **'正在传入视频：{name}'**
  String progImportVideo(String name);

  /// No description provided for @progAttachGuide.
  ///
  /// In zh, this message translates to:
  /// **'正在挂入攻略：{name}'**
  String progAttachGuide(String name);

  /// No description provided for @progRebuildZones.
  ///
  /// In zh, this message translates to:
  /// **'正在重建片区'**
  String get progRebuildZones;

  /// No description provided for @progWriteLibrary.
  ///
  /// In zh, this message translates to:
  /// **'正在写入攻略库'**
  String get progWriteLibrary;

  /// No description provided for @guideFallback.
  ///
  /// In zh, this message translates to:
  /// **'攻略'**
  String get guideFallback;

  /// No description provided for @webDownloadDone.
  ///
  /// In zh, this message translates to:
  /// **'已触发浏览器下载：{filename}'**
  String webDownloadDone(String filename);

  /// No description provided for @unknownPlace.
  ///
  /// In zh, this message translates to:
  /// **'未知地点'**
  String get unknownPlace;

  /// No description provided for @webStorageLabel.
  ///
  /// In zh, this message translates to:
  /// **'浏览器本地存储（Web 预览降级）'**
  String get webStorageLabel;

  /// No description provided for @ledgerFull.
  ///
  /// In zh, this message translates to:
  /// **'白板已满'**
  String get ledgerFull;

  /// No description provided for @nothingImported.
  ///
  /// In zh, this message translates to:
  /// **'没有可导入的照片'**
  String get nothingImported;

  /// No description provided for @dirNotFound.
  ///
  /// In zh, this message translates to:
  /// **'目录不存在：{path}'**
  String dirNotFound(String path);

  /// No description provided for @folderNoPhotos.
  ///
  /// In zh, this message translates to:
  /// **'目录里没有找到照片（jpg/png）'**
  String get folderNoPhotos;

  /// No description provided for @folderAllFailed.
  ///
  /// In zh, this message translates to:
  /// **'目录里的照片都读取失败'**
  String get folderAllFailed;

  /// No description provided for @folderReadFail.
  ///
  /// In zh, this message translates to:
  /// **'读取失败（目录不可访问？）'**
  String get folderReadFail;

  /// No description provided for @webScanUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'浏览器端不支持目录扫描：请用「手动导入」，或在 Windows 桌面端使用'**
  String get webScanUnsupported;

  /// No description provided for @autoImportStats.
  ///
  /// In zh, this message translates to:
  /// **'自动读取：新增 {imported} · 重复跳过 {duplicates}'**
  String autoImportStats(int imported, int duplicates);

  /// No description provided for @assignedTail.
  ///
  /// In zh, this message translates to:
  /// **'，归属攻略 {n}'**
  String assignedTail(int n);

  /// No description provided for @capAdjustTail.
  ///
  /// In zh, this message translates to:
  /// **'（达到取样上限 {n}，可在设置里调大）'**
  String capAdjustTail(int n);

  /// No description provided for @photoImportStats.
  ///
  /// In zh, this message translates to:
  /// **'导入 {imported} 张（定位 {located} · 无定位 {noGps}）'**
  String photoImportStats(int imported, int located, int noGps);

  /// No description provided for @photoDupTail.
  ///
  /// In zh, this message translates to:
  /// **'，重复跳过 {duplicates} 张'**
  String photoDupTail(int duplicates);

  /// No description provided for @dlReport.
  ///
  /// In zh, this message translates to:
  /// **'成功 {ok} · 跳过(已存在) {skip} · 失败 {fail} · {mb} MB'**
  String dlReport(int ok, int skip, int fail, String mb);

  /// No description provided for @shareExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成分享文件'**
  String get shareExportTitle;

  /// No description provided for @shareModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'打包模式'**
  String get shareModeLabel;

  /// No description provided for @modeWatermarked.
  ///
  /// In zh, this message translates to:
  /// **'水印低质版'**
  String get modeWatermarked;

  /// No description provided for @modeOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原片高清版'**
  String get modeOriginal;

  /// No description provided for @modeWatermarkedDesc.
  ///
  /// In zh, this message translates to:
  /// **'照片 ≤960px / 封面 ≤1280px / 视频转 ≤720p，全部烧录水印（不可逆）'**
  String get modeWatermarkedDesc;

  /// No description provided for @modeOriginalDesc.
  ///
  /// In zh, this message translates to:
  /// **'照片与视频按原件字节入包（不缩放、不转码、无水印）；包体上限 1GB；原件全程只读，超限时可剔除条目或降质打包'**
  String get modeOriginalDesc;

  /// No description provided for @webOriginalUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'Web 为降级存储实现，原片模式仅桌面与移动端可用'**
  String get webOriginalUnsupported;

  /// No description provided for @originalVideosNote.
  ///
  /// In zh, this message translates to:
  /// **'原件字节直接入包（不缩码、不转码、无水印）；可先筛掉不需要的照片/视频'**
  String get originalVideosNote;

  /// No description provided for @estOriginalCap.
  ///
  /// In zh, this message translates to:
  /// **'原片合计：{size}（上限 1GB）'**
  String estOriginalCap(String size);

  /// No description provided for @sizeGb.
  ///
  /// In zh, this message translates to:
  /// **'{n} GB'**
  String sizeGb(String n);

  /// No description provided for @filterMediaBtn.
  ///
  /// In zh, this message translates to:
  /// **'筛选打包内容'**
  String get filterMediaBtn;

  /// No description provided for @filterMediaBtnOn.
  ///
  /// In zh, this message translates to:
  /// **'筛选打包内容（已剔除 {n}）'**
  String filterMediaBtnOn(String n);

  /// No description provided for @filterMediaTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择要打包的照片与视频'**
  String get filterMediaTitle;

  /// No description provided for @filterIncluded.
  ///
  /// In zh, this message translates to:
  /// **'已选 {n}/{total}（未勾选的不进入分享包）'**
  String filterIncluded(String n, String total);

  /// No description provided for @tooBigTitle.
  ///
  /// In zh, this message translates to:
  /// **'包体超出上限'**
  String get tooBigTitle;

  /// No description provided for @tooBigMsg.
  ///
  /// In zh, this message translates to:
  /// **'原片包预计 {size}，超过 1 GB 上限。请剔除部分照片 / 视频，或选择下方降质档后按「降质打包」。'**
  String tooBigMsg(String size);

  /// No description provided for @tooBigFilter.
  ///
  /// In zh, this message translates to:
  /// **'去筛选'**
  String get tooBigFilter;

  /// No description provided for @tooBigDegrade.
  ///
  /// In zh, this message translates to:
  /// **'降质打包'**
  String get tooBigDegrade;

  /// No description provided for @degradeHighLabel.
  ///
  /// In zh, this message translates to:
  /// **'高清优先（长边 2048 · q85）'**
  String get degradeHighLabel;

  /// No description provided for @degradeSmallLabel.
  ///
  /// In zh, this message translates to:
  /// **'体积优先（长边 1080 · q80）'**
  String get degradeSmallLabel;

  /// No description provided for @degradeNote.
  ///
  /// In zh, this message translates to:
  /// **'降质只作用于本次打包的副本：临时副本在内存/临时目录生成，打包完成后即清除；相册与攻略中的原图不会被改动。'**
  String get degradeNote;

  /// No description provided for @degradeApplied.
  ///
  /// In zh, this message translates to:
  /// **'降质档：{tier}'**
  String degradeApplied(String tier);

  /// No description provided for @receiverNoteOriginal.
  ///
  /// In zh, this message translates to:
  /// **'接收方导入后可完整查看攻略并可再次导出原片；分享的照片与视频仅存于攻略内，不会进入其地理相册。'**
  String get receiverNoteOriginal;

  /// No description provided for @doneNoteOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原片包不含水印与降质处理；可发给朋友共享原画质，也可留作永久备份副本。'**
  String get doneNoteOriginal;

  /// No description provided for @removeRowTooltip.
  ///
  /// In zh, this message translates to:
  /// **'剔除（保留原文件）'**
  String get removeRowTooltip;

  /// No description provided for @removedToastKeep.
  ///
  /// In zh, this message translates to:
  /// **'已剔除，原文件保留'**
  String get removedToastKeep;

  /// No description provided for @undoBtn.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undoBtn;

  /// No description provided for @removedCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'（已剔除 {n}）'**
  String removedCountSuffix(int n);

  /// No description provided for @removedActionTip.
  ///
  /// In zh, this message translates to:
  /// **'管理已剔除'**
  String get removedActionTip;

  /// No description provided for @removedSheetHint.
  ///
  /// In zh, this message translates to:
  /// **'已剔除的条目不删除原文件，可在此恢复显示'**
  String get removedSheetHint;

  /// No description provided for @restoreBtn.
  ///
  /// In zh, this message translates to:
  /// **'恢复显示'**
  String get restoreBtn;

  /// No description provided for @restoreAllBtn.
  ///
  /// In zh, this message translates to:
  /// **'全部恢复'**
  String get restoreAllBtn;

  /// No description provided for @restoredToastN.
  ///
  /// In zh, this message translates to:
  /// **'已恢复 {n} 条显示'**
  String restoredToastN(int n);

  /// No description provided for @removedListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有已剔除的条目'**
  String get removedListEmpty;

  /// No description provided for @menuExportAll.
  ///
  /// In zh, this message translates to:
  /// **'全量导出'**
  String get menuExportAll;

  /// No description provided for @bundleTitle.
  ///
  /// In zh, this message translates to:
  /// **'全量导出'**
  String get bundleTitle;

  /// No description provided for @bundleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把攻略本全部攻略打包成一个文件（迁移 / 备份用）'**
  String get bundleSubtitle;

  /// No description provided for @bundleIntroCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 篇攻略，将逐个以原片模式打包'**
  String bundleIntroCount(String n);

  /// No description provided for @bundleIntroNote.
  ///
  /// In zh, this message translates to:
  /// **'逐篇导出最高画质（照片与视频原件直通——不缩放、不转码、不加水印），不限制总体积，最终打包为单个 .tgbundle 大包。用于文件迁移与多设备共享；导入端从「加载分享」选择该文件即可整本恢复（已导入过的攻略会自动跳过）。'**
  String get bundleIntroNote;

  /// No description provided for @bundleLedgerHint.
  ///
  /// In zh, this message translates to:
  /// **'其中 {n} 篇攻略挂有相册归属的照片 / 视频，将一并打包'**
  String bundleLedgerHint(String n);

  /// No description provided for @bundleBtnStart.
  ///
  /// In zh, this message translates to:
  /// **'开始全量导出'**
  String get bundleBtnStart;

  /// No description provided for @bundlePreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备…'**
  String get bundlePreparing;

  /// No description provided for @bundlePacking.
  ///
  /// In zh, this message translates to:
  /// **'正在打包第 {k}/{n} 篇：{title}'**
  String bundlePacking(String k, String n, String title);

  /// No description provided for @bundleFileName.
  ///
  /// In zh, this message translates to:
  /// **'AtmaBook_全量备份'**
  String get bundleFileName;

  /// No description provided for @bundleDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'全量导出完成'**
  String get bundleDoneTitle;

  /// No description provided for @bundleDoneDetail.
  ///
  /// In zh, this message translates to:
  /// **'已保存到：{path}\n总体积 {size}'**
  String bundleDoneDetail(String path, String size);

  /// No description provided for @bundleFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'全量导出失败'**
  String get bundleFailedTitle;

  /// No description provided for @bundleFailedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'全量导出失败（没有可打包的攻略）'**
  String get bundleFailedEmpty;

  /// No description provided for @webBundleUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'Web 端无文件系统，全量导出与导入请在桌面 / 移动端使用。'**
  String get webBundleUnsupported;

  /// No description provided for @importBundleProg.
  ///
  /// In zh, this message translates to:
  /// **'正在导入全量包…'**
  String get importBundleProg;

  /// No description provided for @importBundleItem.
  ///
  /// In zh, this message translates to:
  /// **'正在导入：{title}'**
  String importBundleItem(String title);

  /// No description provided for @importBundleInvalid.
  ///
  /// In zh, this message translates to:
  /// **'不是有效的全量导出包（.tgbundle）'**
  String get importBundleInvalid;

  /// No description provided for @importBundleReport.
  ///
  /// In zh, this message translates to:
  /// **'全量导入：成功 {ok} 篇 · 已存在跳过 {skip} 篇 · 失败 {fail} 篇'**
  String importBundleReport(String ok, String skip, String fail);

  /// No description provided for @categoriesColorLabel.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get categoriesColorLabel;

  /// No description provided for @categoriesIconLabel.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get categoriesIconLabel;

  /// No description provided for @categoriesNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get categoriesNameLabel;

  /// No description provided for @categoriesNameHint.
  ///
  /// In zh, this message translates to:
  /// **'分类名称，如：温泉、垂钓'**
  String get categoriesNameHint;

  /// No description provided for @categoriesNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建分类'**
  String get categoriesNewTitle;

  /// No description provided for @categoriesResetDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认样式'**
  String get categoriesResetDefault;

  /// No description provided for @categoriesNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写分类名称'**
  String get categoriesNameRequired;

  /// No description provided for @categoriesDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除该分类？'**
  String get categoriesDeleteTitle;

  /// No description provided for @categoriesDeleteWarn.
  ///
  /// In zh, this message translates to:
  /// **'删除后，已使用该分类的标记将回退为「其他」分类。'**
  String get categoriesDeleteWarn;

  /// No description provided for @categoriesSavedSnack.
  ///
  /// In zh, this message translates to:
  /// **'分类样式已保存'**
  String get categoriesSavedSnack;

  /// No description provided for @categoriesAddedSnack.
  ///
  /// In zh, this message translates to:
  /// **'分类已创建'**
  String get categoriesAddedSnack;

  /// No description provided for @categoriesAddSub.
  ///
  /// In zh, this message translates to:
  /// **'新建自定义分类（名称 + 配色 + 图标）'**
  String get categoriesAddSub;

  /// No description provided for @categoriesImgLabel.
  ///
  /// In zh, this message translates to:
  /// **'图片图标（本地图片替代 Pin 图标）'**
  String get categoriesImgLabel;

  /// No description provided for @categoriesImgUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传图片'**
  String get categoriesImgUpload;

  /// No description provided for @categoriesImgReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换图片'**
  String get categoriesImgReplace;

  /// No description provided for @categoriesImgClear.
  ///
  /// In zh, this message translates to:
  /// **'撤下图片'**
  String get categoriesImgClear;

  /// No description provided for @categoriesImgEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未上传 · 使用上面选中的内置图标'**
  String get categoriesImgEmpty;

  /// No description provided for @categoriesImgCurrent.
  ///
  /// In zh, this message translates to:
  /// **'已上传 · 地图 Pin 与各界面将显示该图片'**
  String get categoriesImgCurrent;

  /// No description provided for @categoriesImgHint.
  ///
  /// In zh, this message translates to:
  /// **'需 1:1 正方形图片（不超过 512×512）；上传后替代 Pin 图标显示，尺寸与内置图标一致；选内置图标或撤下即可还原。'**
  String get categoriesImgHint;

  /// No description provided for @categoriesImgNotSquare.
  ///
  /// In zh, this message translates to:
  /// **'图片需为 1:1 正方形（当前边长不等），请裁成方形后再上传'**
  String get categoriesImgNotSquare;

  /// No description provided for @categoriesImgSaved.
  ///
  /// In zh, this message translates to:
  /// **'图片图标已保存，保存后生效'**
  String get categoriesImgSaved;

  /// No description provided for @categoriesImgFail.
  ///
  /// In zh, this message translates to:
  /// **'图片读取/保存失败，请换一张图片'**
  String get categoriesImgFail;

  /// No description provided for @categoriesColorHex.
  ///
  /// In zh, this message translates to:
  /// **'颜色 #{hex}'**
  String categoriesColorHex(String hex);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
