// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navTitleSettings => 'Settings';

  @override
  String get secPinStyle => 'Pin Style';

  @override
  String get settingsPinModeIconsLabel => 'Icon pins';

  @override
  String get settingsPinModeColoredLabel => 'Color pins';

  @override
  String get pinHintIcons =>
      'Rounded pins embed the category glyph — rich at a glance.';

  @override
  String get pinHintColored =>
      'Plain solid pins separate place types by color — a cleaner map.';

  @override
  String get secMapSource => 'Default Map Source';

  @override
  String get mapHomeTitle => 'Domestic guide → AMap vector';

  @override
  String get mapHomeSub => 'GCJ-02 coordinates, auto-converted to WGS-84';

  @override
  String get mapAbroadTitle => 'Overseas guide → OpenStreetMap';

  @override
  String get mapAbroadSub => 'WGS-84, worldwide';

  @override
  String get mapSourceFoot =>
      'Picked automatically by rule: guides created inside China use AMap, abroad use OSM. You can switch the source any time on the map page.';

  @override
  String get secZone => 'Touring Zones (Clustering)';

  @override
  String get zoneRadiusLabel => 'Default zone radius';

  @override
  String get zoneMinPtsLabel => 'Min places per zone';

  @override
  String get zoneHint =>
      'Must-visit places under the minimum count become standalone zones (own color, no routes). Radius = distance from the circle\'s center to its edge (a 1 km radius makes a circle about 2 km wide, not the diameter). Dense downtown sights: 1–3 km; touring across cities: 5–10 km. When two zone circles overlap, the one with more members stays as the primary zone and the other shrinks automatically.';

  @override
  String get secShare => 'Sharing';

  @override
  String get watermarkLabel => 'Watermark text';

  @override
  String get watermarkHint => 'Shared from AtmaBook';

  @override
  String get watermarkHintText =>
      'When a share file is built, every image in the guide (including the cover) is scaled into a lower-quality copy and burned with the watermark text above (semi-transparent white with black outline, bottom-left). The watermark is irreversible — it protects shared images; originals inside the guide are untouched.';

  @override
  String get secKeys => 'Service Keys (optional)';

  @override
  String get amapKeyLabel => 'AMap Web Key (preferred for domestic search)';

  @override
  String get amapKeyHint =>
      'A web-service key requested on the AMap Open Platform';

  @override
  String get tdtKeyLabel => 'Tianditu tk (enables Tianditu tiles)';

  @override
  String get tdtKeyHint => 'A developer key requested on the Tianditu website';

  @override
  String get keysFoot =>
      'The AMap Web Key only sharpens domestic place search; the Tianditu tk enables the Tianditu tile source. Without keys, keyless Nominatim search is used and offline map packs are unaffected.';

  @override
  String get secCategories => 'Place Categories';

  @override
  String get secDanger => 'Danger Zone';

  @override
  String get clearAllTitle => 'Clear all my guides';

  @override
  String get clearAllSub =>
      'Deletes every guide (incl. markers / photos / zones) and the matching image files — unrecoverable; the demo guide returns on restart';

  @override
  String get clearAllDialogTitle => 'Clear all guides?';

  @override
  String get clearAllDialogContent =>
      'This deletes every current guide (incl. markers / photos / zones) and their image files in the app data directory. This cannot be undone.\n\nTo keep a guide, export it first with “Build share file” from inside the guide.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmClear => 'Confirm clear';

  @override
  String clearedToast(int n) {
    return 'Cleared $n guides (image files deleted)';
  }

  @override
  String get secAbout => 'About';

  @override
  String aboutVersion(String v) {
    return 'Version $v';
  }

  @override
  String get aboutLocalOnly =>
      'All data stays on this device — no cloud services';

  @override
  String get aboutMapSources => 'Map sources: AMap / Tianditu / OSM / Esri';

  @override
  String get aboutMapSourcesSub =>
      'Tiles are for personal offline use; sources are credited in the app';

  @override
  String get secLanguage => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get langChinese => '中文';

  @override
  String get langEnglish => 'English';

  @override
  String get languageHint => 'Applies instantly — defaults to Chinese.';

  @override
  String get homeSearchHint => 'Search titles & summaries';

  @override
  String get tooltipSearch => 'Search';

  @override
  String get tooltipCloseSearch => 'Close search';

  @override
  String get tooltipMenu => 'Menu';

  @override
  String get fabNew => 'New';

  @override
  String menuDirLabel(String dir) {
    return 'Data directory: $dir';
  }

  @override
  String get dirUnavailable => 'Unavailable';

  @override
  String get menuToggleListView => 'List view';

  @override
  String get menuToggleGridView => 'Grid view';

  @override
  String get menuGallery => 'Geo Album';

  @override
  String get menuOfflineMap => 'Offline Maps';

  @override
  String get menuLoadShare => 'Load Share File';

  @override
  String get menuSettings => 'Settings';

  @override
  String get homeEmptyTitle => 'Your guide book is empty';

  @override
  String get homeEmptyHint =>
      'No guides yet.\nTap “New” at the bottom right to pin the places you want on a map.';

  @override
  String homeNoResult(String query) {
    return 'No guides match “$query”';
  }

  @override
  String mustVisitBadge(int n) {
    return '$n must-visit';
  }

  @override
  String placesUnit(int n) {
    return '$n places';
  }

  @override
  String get sharedSuffix => ' (Shared)';

  @override
  String get noSummaryParen => '(No summary)';

  @override
  String get regionDomestic => 'Domestic';

  @override
  String get regionAbroad => 'Abroad';

  @override
  String get guideActionOpenMap => 'Open map';

  @override
  String get guideActionInfo => 'Guide info';

  @override
  String get guideActionDelete => 'Delete guide';

  @override
  String get deleteGuideTitle => 'Delete this guide?';

  @override
  String deleteGuideContent(String title) {
    return '“$title” and its local text/photo records will be removed from the guide book.';
  }

  @override
  String get btnDelete => 'Delete';

  @override
  String deletedToast(String title) {
    return '“$title” deleted (JSON and local files cleaned up)';
  }

  @override
  String importedToast(String name) {
    return 'Imported “$name”';
  }

  @override
  String get importProgressTitle => 'Import Shared Guide';

  @override
  String get importUnpacking => 'Unpacking & verifying share file…';

  @override
  String get importAwaitingConfirm =>
      'Imported before — awaiting confirmation…';

  @override
  String get importRemapping => 'Remapping & writing files…';

  @override
  String get importCancelling => 'Cancelling…';

  @override
  String get btnImportAgain => 'Import again';

  @override
  String get importedBeforeTitle => 'Guide already imported';

  @override
  String importedBeforeContent(String title) {
    return '“$title” was imported before.\nImporting again creates an independent copy (existing data is not overwritten).';
  }

  @override
  String get importCancelled => 'Import cancelled';

  @override
  String get importInvalidFile => 'Not a valid share file';

  @override
  String get importTooLarge => 'File exceeds 1 GB — import rejected';

  @override
  String get importFailedTitle => 'Import failed';

  @override
  String get importFailedPrefix => 'Import failed: ';

  @override
  String get btnOk => 'OK';

  @override
  String get shareFileTypeLabel => 'Shared guide file';

  @override
  String get createStep1 => 'Guide Info';

  @override
  String get createStep2 => 'Scope & Area';

  @override
  String get createTitleHint => 'Guide title, e.g. Two Days in Hangzhou';

  @override
  String get createSummaryHint => 'Summary (optional)';

  @override
  String get createRegionTitle => 'Guide region';

  @override
  String get createCoverTitle => 'Cover image';

  @override
  String get createAddCover => 'Add cover image';

  @override
  String get createNoPhotoPick =>
      'Photo picking is not supported on this platform';

  @override
  String get createNext => 'Next: choose scope';

  @override
  String get createPrev => 'Back';

  @override
  String get createSkipStart => 'Skip — start with online maps';

  @override
  String createBanner(String where, String source) {
    return 'This guide sits “$where”; default map: $source';
  }

  @override
  String get createWhereChina => 'in China';

  @override
  String get createWhereAbroad => 'outside China';

  @override
  String get createSourceAmap => 'AMap vector';

  @override
  String get createSourceOsm => 'OpenStreetMap';

  @override
  String get regionTileChina => 'In China';

  @override
  String get regionTileOverseas => 'Outside China';

  @override
  String get regionTileChinaDesc => 'AMap by default (GCJ-02 auto-converted)';

  @override
  String get regionTileOverseasDesc => 'OpenStreetMap by default (WGS-84)';

  @override
  String get createSearchHint => 'Search a city or place, e.g. Paris / London';

  @override
  String get createScopeFoot =>
      'Downloaded map packs work offline; you can switch online sources any time on the map page. The chosen city becomes the guide\'s scope.';

  @override
  String get createHotTitle => 'Try these popular cities (online search)';

  @override
  String get createHotFoot =>
      'You can also just “Skip” — zoom and locate manually on the map later. Search results come from Nominatim (OpenStreetMap); setting an AMap key in Settings makes domestic searches prefer AMap.';

  @override
  String get createSearchError =>
      'Search failed — check your connection. (Set an AMap key in Settings for better domestic accuracy.)';

  @override
  String get createNoMatch => 'No matching place — try another keyword';

  @override
  String get createBtnUseLocal => 'Use offline pack';

  @override
  String get createBtnUse => 'Use';

  @override
  String get createBtnDownload => 'Download';

  @override
  String createPackReady(String name) {
    return '“$name” is downloaded — offline use, no data traffic';
  }

  @override
  String get createDemoDone => 'Demo download complete';

  @override
  String get createNoPack =>
      'No offline pack for this area yet — you can use online maps';

  @override
  String get createPackFallbackName => 'Offline map pack';

  @override
  String get legendTitle => 'Legend';

  @override
  String legendZoneNumbered(int n) {
    return 'Touring Area $n';
  }

  @override
  String legendZoneNamed(int n, String name) {
    return 'Touring Area $n ($name)';
  }

  @override
  String legendZonePoints(int n) {
    return '$n place(s)';
  }

  @override
  String get catNameScenic => 'Sightseeing';

  @override
  String get catNameDining => 'Dining';

  @override
  String get catNameHotel => 'Stay';

  @override
  String get catNameShopping => 'Shopping';

  @override
  String get catNameTransport => 'Transit';

  @override
  String get catNameOther => 'Other';

  @override
  String get srcAmapVector => 'AMap Vector';

  @override
  String get srcAmapSatellite => 'AMap Satellite';

  @override
  String get srcOsm => 'OpenStreetMap';

  @override
  String get srcEsriStreet => 'Esri Streets (no key)';

  @override
  String get srcEsriTopo => 'Esri Terrain (no key)';

  @override
  String get srcEsriGray => 'Esri Light Gray (no key)';

  @override
  String get srcEsriSatellite => 'Esri Satellite';

  @override
  String get srcTianditu => 'Tianditu';

  @override
  String get srcKindVector => 'Vector base map';

  @override
  String get srcKindSatellite => 'Satellite imagery';

  @override
  String get srcTdtKeySuffix => ' · Tianditu tk required in Settings';

  @override
  String get mapTooltipLayers => 'Layers & photos';

  @override
  String get mapTooltipSource => 'Map source';

  @override
  String get mapTooltipMore => 'More';

  @override
  String get mapMenuNotes => 'Guide notes';

  @override
  String get mapMenuZoneParams => 'Reset params';

  @override
  String get mapMenuShare => 'Build shares';

  @override
  String get mapFabLocate => 'Location lands here together with photos later';

  @override
  String get mapHintPill =>
      'Tap a pin for details · long-press the map to add a marker';

  @override
  String get mapFabMarkers => 'Marker';

  @override
  String get layersTitle => 'Map layers';

  @override
  String get layerMarkers => 'Place markers';

  @override
  String get layerMarkersSub => 'Color-coded pin icons by category';

  @override
  String get layerZoneCircles => 'Touring-area circles';

  @override
  String get layerZoneCirclesSub =>
      'Clustering bands of must-visit spots (reset params via the ⋮ menu)';

  @override
  String get layerPhotosTitle => 'Geo Album · Photo layer';

  @override
  String get layerPhotosSub =>
      'Photos & videos with GPS overlay the guide map; off keeps a pure guide map (same toggle in reverse on the Geo Album page)';

  @override
  String get recalcTitle => 'Recompute touring areas';

  @override
  String get recalcSub =>
      'Auto-recomputed when radius or must-visit changes; refresh here on demand';

  @override
  String get snackRecalcRunning => 'Recomputing touring areas…';

  @override
  String get zoneDialogTitle => 'Reset touring-area params';

  @override
  String get zoneRadiusDialogTitle => 'Touring-area radius';

  @override
  String get zoneDialogFoot =>
      'Radius = distance from the circle\'s center to its edge (a 1 km radius makes a circle about 2 km wide, not the diameter); DBSCAN uses it to decide whether must-visit spots cluster into one touring area.';

  @override
  String get zoneDialogFollowState =>
      'This guide currently follows global settings; an override applies only to this guide.';

  @override
  String get zoneDialogOverridden =>
      'This guide has its own params — tap “Restore global settings” to revert.';

  @override
  String get snackZoneRestored =>
      'Restored to global settings — recomputing touring areas…';

  @override
  String get btnRestoreGlobal => 'Restore global settings';

  @override
  String get btnApplyRecalc => 'Apply & recompute';

  @override
  String get snackZoneApplied =>
      'Touring areas recomputed with the new params (this guide only)';

  @override
  String get srcSheetTitle => 'Choose map source';

  @override
  String get srcSheetIntro =>
      'Domestic guides default to AMap (GCJ-02 auto-converted), overseas to OpenStreetMap. Downloaded offline tile packs are listed below — tap to use them even without a network.';

  @override
  String get srcTagChinaRec => 'Domestic pick';

  @override
  String get srcTagOverseasRec => 'Overseas pick';

  @override
  String get srcTagWebNoDownload => 'Not downloadable in web app';

  @override
  String get srcPacksNone =>
      '(No offline packs yet — create a download on the “Offline Maps” page and it will show up here)';

  @override
  String get offlinePrefix => '[Offline]';

  @override
  String tileCountUnit(int n) {
    return '$n tiles';
  }

  @override
  String get srcHintEsri => ' · Key-free; fetches fine in browsers';

  @override
  String get srcHintOsm =>
      ' · Often unreachable from China; test the connection before downloading';

  @override
  String get snackNeedsTdtKey =>
      'Tianditu needs a tk key first — Settings → Service keys';

  @override
  String snackPackSwitched(String name) {
    return 'Switched to offline pack “$name”';
  }

  @override
  String get infoSheetTitle => 'Guide info';

  @override
  String get infoSheetSub =>
      'Title, summary and cover can be edited any time — home cards sync instantly';

  @override
  String get infoTitleHint => 'Guide title';

  @override
  String get infoSummaryHint => 'Summary';

  @override
  String get infoCoverTitle => 'Cover image (optional)';

  @override
  String get infoChangeCover => 'Change';

  @override
  String get infoRemoveCover => 'Remove';

  @override
  String get infoAddCover =>
      'Add a cover image (a color-block cover is used otherwise)';

  @override
  String get infoSaved => 'Guide info updated (JSON and cover saved)';

  @override
  String get btnSave => 'Save';

  @override
  String get editNewTitle => 'New place';

  @override
  String get editEditTitle => 'Edit place';

  @override
  String get editIconNotSaved => 'Storage unavailable — custom icon not saved';

  @override
  String get editTitleRequired => 'Enter the place name';

  @override
  String get markerAdded => 'Marker added';

  @override
  String get markerSaved => 'Changes saved';

  @override
  String get groupIdentity => 'Name & category';

  @override
  String get editTitleHint => 'Place name, e.g. West Lake · Broken Bridge';

  @override
  String get groupPinStyle => 'Pin style';

  @override
  String get pinUploadCustom => 'Upload custom pin icon';

  @override
  String get pinChangeIcon => 'Change pin icon';

  @override
  String get pinResetIcon => 'Restore default icon';

  @override
  String get groupRules => 'Visit rules';

  @override
  String get mustSwitchTitle => 'Must-visit place';

  @override
  String get mustSwitchSub =>
      'Checking “Must-visit” joins touring-area clustering and route ordering; “Optional” stays as a backup suggestion';

  @override
  String get gpsCoordTitle => 'GPS coordinates (WGS-84)';

  @override
  String get latNorth => 'N';

  @override
  String get latSouth => 'S';

  @override
  String get lngEast => 'E';

  @override
  String get lngWest => 'W';

  @override
  String get copyCoords => 'Copy coordinates';

  @override
  String get coordsCopied => 'Coordinates copied';

  @override
  String get repickOnMap => 'Re-pick on map';

  @override
  String get verifyNav => 'Test navigation';

  @override
  String get groupDetails => 'Details';

  @override
  String get editDescHint => 'Opening hours, tips, what to avoid…';

  @override
  String get groupPhotos => 'Photos';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get groupLinks => 'Related links';

  @override
  String get linkInvalid => 'This link is invalid';

  @override
  String get addLink => 'Add link';

  @override
  String get noLinks => 'No links yet';

  @override
  String get linkDialogTitle => 'Add link';

  @override
  String get linkNameHint => 'Link name, e.g. Official tickets';

  @override
  String get linkDefaultName => 'Link';

  @override
  String get urlRequired => 'Enter a URL';

  @override
  String get btnAdd => 'Add';

  @override
  String get mustVisitTag => 'Must-visit';

  @override
  String get optionalTag => 'Optional';

  @override
  String photosSection(int n) {
    return 'Photos ($n)';
  }

  @override
  String get noPhotosHint => 'No photos yet — tap “Details” to add some.';

  @override
  String get navHere => 'Navigate here';

  @override
  String get editDetails => 'Details';

  @override
  String get deleteMarkerTitle => 'Delete this marker?';

  @override
  String deleteMarkerContent(String title) {
    return '“$title” and its text/photo records will be removed.';
  }

  @override
  String markerDeletedToast(String title) {
    return '“$title” deleted';
  }

  @override
  String drawerTitle(int n) {
    return 'Markers ($n)';
  }

  @override
  String get filterAll => 'All';

  @override
  String get sortCategory => 'Type';

  @override
  String get sortZone => 'Zone';

  @override
  String get sortTime => 'Time';

  @override
  String get drawerEmpty => 'No markers match this filter';

  @override
  String imageCount(int n) {
    return '$n photos';
  }

  @override
  String get pickPointTitle => 'Re-pick on map';

  @override
  String get pickConfirm => 'Use this location';

  @override
  String get navAmapFail =>
      'Could not open a map — coordinates copied to clipboard';

  @override
  String get navUrlFail => 'Could not open the link (browser/platform limit)';

  @override
  String get tilesTitle => 'Offline maps';

  @override
  String get fabNewPack => 'New download pack';

  @override
  String get deletePackTitle => 'Delete this offline pack?';

  @override
  String deletePackContent(String name, int n) {
    return '$n tile files of “$name” will be deleted and the space freed; offline basemaps of related guides will stop matching it.';
  }

  @override
  String packDeletedToast(String name) {
    return '“$name” deleted — space freed';
  }

  @override
  String get tilesEmptyTitle => 'No offline packs yet';

  @override
  String get tilesEmptyHint =>
      'Tap “New download pack” at the bottom right, frame an area and zoom levels, then download.';

  @override
  String get bannerTitle => 'Local tile packs';

  @override
  String get bannerSub =>
      'Once an area and zoom levels are downloaded, that region\'s map opens without a network; deleting frees the space.';

  @override
  String get tilesFoot =>
      'Desktop: for China use AMap (great detail, GCJ-02 auto-converted); overseas OSM / Esri. In browsers: Esri family first (key-free — AMap is CORS-blocked, OSM is often unreachable from China). Each +1 zoom ≈ ×4 tiles; be careful with large ranges at high zoom; run the connectivity test before downloading.';

  @override
  String dateMthDy(String m, String d) {
    return '$m/$d';
  }

  @override
  String completedOn(String date) {
    return 'Done $date';
  }

  @override
  String get menuRefill => 'Redownload missing tiles';

  @override
  String get snackRefillUnavailable =>
      'Incremental refill opens by demand after milestone M6';

  @override
  String get wizardTitle => 'New offline tile pack';

  @override
  String get stepChooseSource => 'Choose map source';

  @override
  String get stepSelectArea => 'Frame download area';

  @override
  String get stepChooseZoom => 'Choose zoom levels';

  @override
  String get stepConfirm => 'Confirm & download';

  @override
  String get wizardNeedRange =>
      'Tap two diagonal corners on the map to frame an area first';

  @override
  String get rangeTooSmall =>
      'Area too small or zoom too low — adjust the area/levels';

  @override
  String get hugeConfirmTitle => 'Large area — download anyway?';

  @override
  String hugeConfirmContent(int n, String mb) {
    return '$n tiles in total (≈ $mb MB or more). Time depends on the network; you can cancel any time and kept tiles stay usable.';
  }

  @override
  String get btnRethink => 'Reconsider';

  @override
  String get btnContinueDownload => 'Continue download';

  @override
  String progressInit(int n) {
    return '0 / $n · 4 parallel · 2 retries';
  }

  @override
  String progressText(int done, int total, String mb) {
    return '$done / $total · $mb MB (kept tiles resume)';
  }

  @override
  String get cancelReasonWebCgj =>
      'Blocked in-browser by AMap CORS: switch to an Esri source, or download AMap on the Windows desktop app';

  @override
  String get cancelReasonWeb =>
      'In-browser requests blocked by the target site\'s CORS (or offline) — try the OSM source';

  @override
  String get cancelReasonOffline =>
      'All requests failed in a row (offline or host refuses) — check your network and retry';

  @override
  String get cancelledKept => 'Cancelled (downloaded parts kept)';

  @override
  String reportStats(String reason, int ok, int skip, int fail) {
    return '$reason: ok $ok · skipped $skip · failed $fail';
  }

  @override
  String get snackAbortedKept =>
      'Aborted — kept tiles stay resumable (manifest not written)';

  @override
  String downloadedNoneMsg(int n) {
    return 'No tiles downloaded: $n failed — check your network';
  }

  @override
  String get snackNoneDownloaded =>
      'No tiles downloaded — check your network and retry';

  @override
  String get manifestFail =>
      'Manifest write failed (storage quota?), tiles kept';

  @override
  String get doneLabel => 'Download complete';

  @override
  String get donePartial => 'Done (with failures)';

  @override
  String doneMsgLine(String what, String report, int secs) {
    return '$what: $report · $secs s';
  }

  @override
  String snackPackReady(int n) {
    return 'Offline pack ready ($n tiles) — pick it in the guide\'s map-source sheet';
  }

  @override
  String snackPartialFail(int n) {
    return 'Some tiles failed ($n) — download again to resume';
  }

  @override
  String get packNameUnnamed => 'Unnamed map pack';

  @override
  String get needRangeForProbe => 'Select an area in the framing step first';

  @override
  String get probing => 'Probing connectivity (1 tile live test)…';

  @override
  String get extraWebCgj => ' (AMap is CORS-blocked in the web build)';

  @override
  String probeOk(String status, int ms, String extra) {
    return '✅ Reachable: HTTP $status · $ms ms $extra';
  }

  @override
  String probeFailWeb(String status, int ms) {
    return '❌ Unreachable (HTTP $status · $ms ms) — try an Esri/OSM source, or the Windows desktop app';
  }

  @override
  String probeFailDesktop(String status, int ms) {
    return '❌ Unreachable (HTTP $status · $ms ms) — check your network';
  }

  @override
  String srcRecommendFoot(String note) {
    return 'For China use AMap ($note); overseas OSM / Esri.';
  }

  @override
  String get srcNoteGcj => 'GCJ-02: selected corners auto-converted';

  @override
  String get srcNoteWgs => 'WGS-84';

  @override
  String get webPreviewNote =>
      'Web preview: Esri family first (key-free); AMap is CORS-blocked and OSM is often unreachable from China — run the connectivity test if unsure.';

  @override
  String get areaDone => 'Both diagonal corners set';

  @override
  String get areaHint => 'Tap two diagonal corners on the map below';

  @override
  String get btnClear => 'Clear';

  @override
  String pointLabelA(String value) {
    return 'A: $value';
  }

  @override
  String pointLabelB(String value) {
    return 'B: $value';
  }

  @override
  String get notPicked => 'not set';

  @override
  String get zoomFootStep =>
      'z12–16 suits street-level browsing; each +1 zoom ≈ ×4 tiles — watch capacity and time.';

  @override
  String get rowMapSource => 'Map source';

  @override
  String get rowCoordSys => 'Coordinates';

  @override
  String get coordRowGcj => 'GCJ-02 (corners converted)';

  @override
  String get rowRange => 'Area';

  @override
  String get rowZoom => 'Zoom';

  @override
  String get rowManifest => 'Actual tiles';

  @override
  String manifestValue(int n, String mb) {
    return '$n tiles · ≈ $mb MB';
  }

  @override
  String get manifestPending => 'Select an area first';

  @override
  String get probeBtnValue =>
      'Connectivity test (verifies 1 tile within seconds before downloading)';

  @override
  String get webCgjWarning =>
      'In the web build AMap cannot be fetched across origins (CORS) and downloads will fail. Use an Esri source, or download AMap on the Windows desktop app.';

  @override
  String get startDownload => 'Start download';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get btnNext => 'Next';

  @override
  String videoDupPart(int n) {
    return ' · skipped $n duplicates';
  }

  @override
  String videoFailPart(int n) {
    return ' · $n failed (retry or try another format)';
  }

  @override
  String get videoFullPart => ' · album sampling cap reached';

  @override
  String get videoTailPart =>
      ' — open the videos (Album Library) to set their locations';

  @override
  String videoInsertBanner(
    int imported,
    String dup,
    String fail,
    String full,
    String tail,
  ) {
    return 'Videos inserted: added $imported$dup$fail$full$tail';
  }

  @override
  String get removePhotoTitle => 'Remove photo';

  @override
  String removeGuidePhotoContent(String name) {
    return '\"$name\" will be removed from the geo album and the guide\'s map photos at the same time (re-import to restore).';
  }

  @override
  String get photoUnnamed => 'Unnamed photo';

  @override
  String get removeLedgerPhotoContent =>
      'This photo will be removed from the geo album and the map photos (re-add to restore).';

  @override
  String get removePhotoBtn => 'Remove';

  @override
  String get locateFailSnack =>
      'Could not get your location (browsers need location permission)';

  @override
  String get scanFolderTitle => 'Batch import album folder';

  @override
  String get scanFolderLabel => 'Local folder path';

  @override
  String get scanFolderHint => 'C:\\Users\\you\\Pictures\\travel photos';

  @override
  String get startImport => 'Start import';

  @override
  String batchImportStats(int imported, int duplicates) {
    return 'Batch import: added $imported · skipped $duplicates duplicates';
  }

  @override
  String noGpsTail(int n) {
    return ', $n without location';
  }

  @override
  String capReachedPart(int n) {
    return ' (sampling cap $n reached)';
  }

  @override
  String curateImportStats(int imported, int duplicates) {
    return 'Curated add: added $imported · skipped $duplicates duplicates';
  }

  @override
  String get insertVideosTitle => 'Insert videos';

  @override
  String get insertVideosContent =>
      'Videos are inserted from local files into the geo album ledger.\nSet locations manually: afterwards pick each video\'s shooting spot on the map in the Album Library (videos carry no EXIF location).\n\nBatch: pick a group in one multi-select window; One-by-one: select one at a time and cancel anytime.\nBoth ways end up the same.';

  @override
  String get pickOneByOne => 'One by one';

  @override
  String get pickBatch => 'Batch select';

  @override
  String get videoTypeGroup => 'Videos';

  @override
  String get collectedOne => '1 video collected';

  @override
  String get pickNextAsk => 'Pick the next one?';

  @override
  String get startInsertNow => 'That\'s all — start inserting';

  @override
  String get keepPicking => 'Pick the next one';

  @override
  String pickVideoFail(String err) {
    return 'Video selection failed: $err';
  }

  @override
  String get removedToast => 'Removed';

  @override
  String geoWritten(String coords) {
    return 'Geo tag written: $coords';
  }

  @override
  String get albumLibTooltip =>
      'Album library (all photos · GPS status · map visibility)';

  @override
  String get menuBatchImport => 'Batch import';

  @override
  String get menuCurate => 'Curated Photos';

  @override
  String get menuInsertVideos => 'Insert videos';

  @override
  String get noticeEmpty =>
      'No photos in the geo album yet — use ⋮ (top right) to batch import or add curated';

  @override
  String noticeOnMap(int n) {
    return '$n on the map';
  }

  @override
  String noticeMissing(int n) {
    return '$n without GPS not shown';
  }

  @override
  String noticeAllShown(int n) {
    return '$n photos on the map — zoom in to see more';
  }

  @override
  String get baseMapAmap => 'Basemap © AMap';

  @override
  String get baseMapEsri =>
      'Basemap © Esri (AMap unreachable — switched automatically)';

  @override
  String get baseMapOsm =>
      'Basemap © OpenStreetMap (both AMap and Esri unreachable)';

  @override
  String baseSwitchSnack(String name) {
    return 'AMap basemap unreachable — switched to: $name';
  }

  @override
  String get albumLibTitle => 'Album library';

  @override
  String get albumLibEmpty => 'The album library is empty';

  @override
  String get albumLibEmptyHint =>
      'Go back to the geo album and add via the ⋮ menu — batch import / curated add';

  @override
  String get sourceAlbumImport => 'Album import';

  @override
  String sourceGuide(String title) {
    return 'Guide · $title';
  }

  @override
  String get sourceGuidePhoto => 'Guide photos';

  @override
  String get geoUpdated => 'Location updated';

  @override
  String currentGeoLabel(String coords) {
    return 'Current location $coords';
  }

  @override
  String get editGeoTitle => 'Edit location';

  @override
  String get editGeoHint =>
      'Re-pick on the location map; confirming overrides this item\'s current spot';

  @override
  String videoRowTitle(String dur) {
    return 'Video$dur';
  }

  @override
  String rowGps(String coords) {
    return 'GPS $coords — long-press row to edit';
  }

  @override
  String get rowNoGeoVideo =>
      'No location (open viewer to set the shooting spot)';

  @override
  String get rowNoGps => 'No GPS (add a tag while viewing)';

  @override
  String get curateTitle => 'Curated add (tick photos to join)';

  @override
  String curateAdd(int n) {
    return 'Add $n photos';
  }

  @override
  String get viewPhotosTitle => 'Viewing photos';

  @override
  String playWithDuration(String dur) {
    return 'Play · $dur';
  }

  @override
  String get playVideoBtn => 'Play video';

  @override
  String get geoTagTitle => 'Set geo tag';

  @override
  String get pickHint => 'Zoom to the right area, then tap the target spot';

  @override
  String get pickedHint => 'Spot dropped — keep tapping to fine-tune';

  @override
  String get noLocationYet => 'No spot selected';

  @override
  String get confirmLocation => 'Confirm this spot';

  @override
  String get removeThisPhoto => 'Remove this one';

  @override
  String get photoWallNoGuides => 'No guides yet';

  @override
  String get mapPhotosSuffix => ' · Map Photos';

  @override
  String importParsing(String n) {
    return 'Parsing EXIF and generating thumbnails… ($n)';
  }

  @override
  String importAllDup(String n) {
    return 'All selected are duplicates ($n) — nothing imported';
  }

  @override
  String importFail(String err) {
    return 'Import failed: $err';
  }

  @override
  String get switchGuideTip => 'Switch guide';

  @override
  String get sortNewTip => 'Shot time: new → old';

  @override
  String get sortOldTip => 'Shot time: old → new';

  @override
  String get photoListTip => 'Photo list (located/unlocated)';

  @override
  String get importPhotosTip => 'Import photos';

  @override
  String get layerPhotosOnly => 'Photos only';

  @override
  String get layerWithMarkers => '+Markers';

  @override
  String markerOnPhotoMap(String title) {
    return 'Marker \"$title\" — see details on the guide\'s map page';
  }

  @override
  String photoListStats(String total, String located, String unlocated) {
    return 'Photos $total · located $located · unlocated $unlocated';
  }

  @override
  String get sectionUnlocated => 'Unlocated';

  @override
  String boundPrefix(String title) {
    return 'bound to \"$title\" · ';
  }

  @override
  String get noLocBindTip => 'No location (tap to bind a marker)';

  @override
  String get bindBtn => 'Bind';

  @override
  String get renamePhotoTitle => 'Rename photo';

  @override
  String get renamePhotoHint =>
      'e.g. \"Sunrise · tea field\" (empty shows the shot time)';

  @override
  String get nameReset => 'Name reset';

  @override
  String renamedTo(String name) {
    return 'Renamed to: $name';
  }

  @override
  String get deletePhotoTitle => 'Delete photo';

  @override
  String deletePhotoContent(String title) {
    return 'The photo and its full/thumb files will be deleted from the guide.\n\n$title';
  }

  @override
  String get photoDeleted => 'Photo deleted (files cleaned up)';

  @override
  String get unboundToast => 'Binding removed';

  @override
  String boundToast(String name) {
    return 'Bound to: $name';
  }

  @override
  String get renameTip => 'Rename';

  @override
  String latLngLine(String lat, String lng) {
    return 'Lat $lat · Lng $lng';
  }

  @override
  String noExifLine(String tail) {
    return 'No EXIF location$tail';
  }

  @override
  String get exifFollowTail => ' (follows its bound marker)';

  @override
  String get changeBindBtn => 'Change binding';

  @override
  String boundMarkerLine(String title, String tail) {
    return 'Bound marker: $title$tail';
  }

  @override
  String get shownAtMarkerTail => ' (shown at the marker)';

  @override
  String get videoPlayTitle => 'Video playback';

  @override
  String playerError(String msg) {
    return 'Playback error: $msg';
  }

  @override
  String pathError(String msg) {
    return 'File path unavailable: $msg';
  }

  @override
  String get btnBack => 'Back';

  @override
  String get bindToMarker => 'Bind to marker';

  @override
  String get changeBindTitle => 'Change bound marker';

  @override
  String get bindNoMarkers => 'No markers yet — add some on the map page first';

  @override
  String distToShot(String dist) {
    return '$dist from the shot location';
  }

  @override
  String get unbindLine => 'Unbind';

  @override
  String get notesTitle => 'Guide notes';

  @override
  String get notesEmptyHint =>
      'No places in this guide yet — add them on the map first: long-press the map to create a marker';

  @override
  String get viewOnMapTip => 'View on the guide\'s map';

  @override
  String zoneCountChip(String n) {
    return '$n touring areas';
  }

  @override
  String scenicCountChip(String n) {
    return '$n places';
  }

  @override
  String get recommendedTail => ' · Recommended stay';

  @override
  String zoneLabelN(String n) {
    return 'Touring Area $n';
  }

  @override
  String zoneRange(String r, String a) {
    return 'Radius $r · ≈ $a k㎡';
  }

  @override
  String kmFromStart(String d) {
    return '$d km from start';
  }

  @override
  String get zoneEmpty => 'No places registered in this touring area';

  @override
  String get secDiningRec => 'Eateries nearby';

  @override
  String get secShoppingRec => 'Shopping nearby';

  @override
  String get secScenic => 'Sights';

  @override
  String get secDining => 'Dining';

  @override
  String get secShopping => 'Shopping';

  @override
  String get secOther => 'Others';

  @override
  String photosTotalN(String n) {
    return '$n photos';
  }

  @override
  String get noPhotoYet => 'No photo';

  @override
  String get mustVisitStar => '  ★Must-visit';

  @override
  String get descMissing => 'No details yet';

  @override
  String get navBtnShort => 'Navigate';

  @override
  String get stayHead => 'Your stay · tour start';

  @override
  String get stayPlan => 'Touring areas ordered nearest first';

  @override
  String get otherRecTitle =>
      'Other recommendations (outside all touring areas)';

  @override
  String get flatBanner =>
      'This guide has no must-visit spots yet, so no touring areas were formed: all registered places are listed flat by category (stays on top). Mark places as \"Must-visit\" on the map and the guide notes will re-organize by touring areas.';

  @override
  String get preparing => 'Preparing…';

  @override
  String estMb(String n) {
    return '≈ $n MB';
  }

  @override
  String estKb(String n) {
    return '≈ $n KB';
  }

  @override
  String exportStats(String m, String ph, String v, String cl) {
    return 'Markers $m · photos $ph · videos $v · touring areas $cl';
  }

  @override
  String estTotal(String est) {
    return 'Estimated size: $est';
  }

  @override
  String get includePhotosTitle =>
      'Include guide photos (low-quality copies + watermark)';

  @override
  String get wmFromSettings => 'Watermark text from settings (customizable)';

  @override
  String get videoTransTail =>
      '; videos transcoded to ≤720p with a burned-in watermark';

  @override
  String get noPhotosDesc =>
      'Exports markers / touring areas / text only — smallest size';

  @override
  String get receiverNote =>
      'The receiver imports the full guide; shared photos & videos live inside the guide and never enter their geo album.';

  @override
  String get genBtn => 'Generate .tgshare file';

  @override
  String get workingTitle => 'Generating the share file…';

  @override
  String progressLine(String d, String n, String label) {
    return '$d/$n done: $label';
  }

  @override
  String get doneTitle => 'Generated';

  @override
  String get doneNote =>
      'Send this file to anyone with the app — \"Import shared guide\" opens it; it also works as your permanent backup.';

  @override
  String get btnFinish => 'Done';

  @override
  String get failedTitle => 'Generation failed';

  @override
  String get retryBtn => 'Back & retry';

  @override
  String get progStructured => 'Structured data';

  @override
  String get progManifest => 'Manifest';

  @override
  String get progCover => 'Cover';

  @override
  String progPhoto(String name) {
    return 'Photo $name';
  }

  @override
  String progThumb(String name) {
    return 'Thumb $name';
  }

  @override
  String progImage(String name) {
    return 'Image $name';
  }

  @override
  String progTranscode(String name) {
    return 'Transcoding $name';
  }

  @override
  String progVideo(String name) {
    return 'Video $name';
  }

  @override
  String get progWriteCover => 'Writing cover';

  @override
  String progImportImage(String name) {
    return 'Importing image: $name';
  }

  @override
  String progGenMap(String name) {
    return 'Generating map: $name';
  }

  @override
  String progImportPhoto(String name) {
    return 'Importing photo: $name';
  }

  @override
  String progGenThumb(String name) {
    return 'Generating thumb: $name';
  }

  @override
  String progImportVideo(String name) {
    return 'Importing video: $name';
  }

  @override
  String progAttachGuide(String name) {
    return 'Attaching to guide: $name';
  }

  @override
  String get progRebuildZones => 'Rebuilding touring areas';

  @override
  String get progWriteLibrary => 'Writing guide library';

  @override
  String get guideFallback => 'Guide';

  @override
  String webDownloadDone(String filename) {
    return 'Browser download started: $filename';
  }

  @override
  String get unknownPlace => 'Unknown place';

  @override
  String get webStorageLabel => 'In-browser storage (web preview fallback)';

  @override
  String get ledgerFull => 'Album ledger is full';

  @override
  String get nothingImported => 'No photos to import';

  @override
  String dirNotFound(String path) {
    return 'Folder not found: $path';
  }

  @override
  String get folderNoPhotos => 'No photos (jpg/png) found in the folder';

  @override
  String get folderAllFailed => 'Every photo in the folder failed to read';

  @override
  String get folderReadFail => 'Read failed (folder inaccessible?)';

  @override
  String get webScanUnsupported =>
      'Folder scanning is not supported in browsers — use \"manual import\", or the Windows desktop app';

  @override
  String autoImportStats(int imported, int duplicates) {
    return 'Auto read: added $imported · skipped $duplicates';
  }

  @override
  String assignedTail(int n) {
    return ', $n assigned to guides';
  }

  @override
  String capAdjustTail(int n) {
    return ' (sampling cap $n reached — raise it in settings)';
  }

  @override
  String photoImportStats(int imported, int located, int noGps) {
    return 'Imported $imported ($located located · $noGps without)';
  }

  @override
  String photoDupTail(int duplicates) {
    return ', skipped $duplicates duplicates';
  }

  @override
  String dlReport(int ok, int skip, int fail, String mb) {
    return 'ok $ok · skipped (existing) $skip · failed $fail · $mb MB';
  }

  @override
  String get shareExportTitle => 'Create share file';

  @override
  String get shareModeLabel => 'Package mode';

  @override
  String get modeWatermarked => 'Watermarked copy';

  @override
  String get modeOriginal => 'Original quality';

  @override
  String get modeWatermarkedDesc =>
      'Photos ≤960px / cover ≤1280px / video transcoded to ≤720p, all burned with an irreversible watermark';

  @override
  String get modeOriginalDesc =>
      'Photos and videos are packed as original bytes (no resizing, no transcoding, no watermark); 1 GB cap; originals stay read-only; trim items or degrade to fit';

  @override
  String get webOriginalUnsupported =>
      'Web uses degraded storage — original mode is available on desktop and mobile only';

  @override
  String get originalVideosNote =>
      'Original bytes are packed as-is (no resizing, transcoding or watermark); you can deselect photos/videos first';

  @override
  String estOriginalCap(String size) {
    return 'Originals total: $size (1 GB cap)';
  }

  @override
  String sizeGb(String n) {
    return '$n GB';
  }

  @override
  String get filterMediaBtn => 'Choose packed items';

  @override
  String filterMediaBtnOn(String n) {
    return 'Choose packed items ($n removed)';
  }

  @override
  String get filterMediaTitle => 'Select photos and videos to pack';

  @override
  String filterIncluded(String n, String total) {
    return '$n/$total selected (unchecked items are excluded)';
  }

  @override
  String get tooBigTitle => 'Package exceeds the limit';

  @override
  String tooBigMsg(String size) {
    return 'The original package is about $size, above the 1 GB cap. Remove some photos / videos, or pick a degradation tier below and press \"Pack degraded\".';
  }

  @override
  String get tooBigFilter => 'Choose items';

  @override
  String get tooBigDegrade => 'Pack degraded';

  @override
  String get degradeHighLabel => 'Quality first (≤2048 · q85)';

  @override
  String get degradeSmallLabel => 'Size first (≤1080 · q80)';

  @override
  String get degradeNote =>
      'Degradation applies to this package only: copies are produced in memory/temp files and deleted when packing completes; originals in the album or guide are never modified.';

  @override
  String degradeApplied(String tier) {
    return 'Degradation tier: $tier';
  }

  @override
  String get receiverNoteOriginal =>
      'The receiver can fully view the guide and may re-export originals; shared photos & videos live inside the guide and never enter their geo album.';

  @override
  String get doneNoteOriginal =>
      'The original package contains no watermark or degradation; share it at full quality, or keep it as a permanent backup.';

  @override
  String get removeRowTooltip => 'Remove (keep original file)';

  @override
  String get removedToastKeep => 'Removed — the original file is kept';

  @override
  String get undoBtn => 'Undo';

  @override
  String removedCountSuffix(int n) {
    return ' ($n removed)';
  }

  @override
  String get removedActionTip => 'Manage removed items';

  @override
  String get removedSheetHint =>
      'Removed items keep their original files — restore display anytime';

  @override
  String get restoreBtn => 'Restore';

  @override
  String get restoreAllBtn => 'Restore all';

  @override
  String restoredToastN(int n) {
    return 'Restored $n';
  }

  @override
  String get removedListEmpty => 'Nothing removed';

  @override
  String get menuExportAll => 'Export all';

  @override
  String get bundleTitle => 'Export all guides';

  @override
  String get bundleSubtitle =>
      'Pack every guide into a single file for migration / backup';

  @override
  String bundleIntroCount(String n) {
    return '$n guides in total, packed one by one in original mode';
  }

  @override
  String get bundleIntroNote =>
      'Each guide is exported at full quality (photos & videos are packed as original bytes — no resizing, transcoding or watermark) with no size cap, wrapped into a single .tgbundle package. Use it to move files between devices; on the receiving side pick it under \"Load share\" to restore the whole collection (guides already imported are skipped automatically).';

  @override
  String bundleLedgerHint(String n) {
    return '$n guide(s) have geo-album photos / videos attached — they are packed too';
  }

  @override
  String get bundleBtnStart => 'Start export';

  @override
  String get bundlePreparing => 'Preparing…';

  @override
  String bundlePacking(String k, String n, String title) {
    return 'Packing $k/$n: $title';
  }

  @override
  String get bundleFileName => 'AtmaBook_Full_Export';

  @override
  String get bundleDoneTitle => 'Export complete';

  @override
  String bundleDoneDetail(String path, String size) {
    return 'Saved to: $path\nTotal size $size';
  }

  @override
  String get bundleFailedTitle => 'Export failed';

  @override
  String get bundleFailedEmpty => 'Export failed (no guides to pack)';

  @override
  String get webBundleUnsupported =>
      'Web has no file system — full export & import are available on desktop / mobile.';

  @override
  String get importBundleProg => 'Importing full bundle…';

  @override
  String importBundleItem(String title) {
    return 'Importing: $title';
  }

  @override
  String get importBundleInvalid =>
      'Not a valid full-export bundle (.tgbundle)';

  @override
  String importBundleReport(String ok, String skip, String fail) {
    return 'Bundle import: $ok imported · $skip skipped (existing) · $fail failed';
  }

  @override
  String get categoriesColorLabel => 'Color';

  @override
  String get categoriesIconLabel => 'Icon';

  @override
  String get categoriesNameLabel => 'Name';

  @override
  String get categoriesNameHint => 'Category name, e.g. Hot springs, Fishing';

  @override
  String get categoriesNewTitle => 'New Category';

  @override
  String get categoriesResetDefault => 'Reset to default';

  @override
  String get categoriesNameRequired => 'Please enter a category name';

  @override
  String get categoriesDeleteTitle => 'Delete this category?';

  @override
  String get categoriesDeleteWarn =>
      'Markers using this category will fall back to \"Other\".';

  @override
  String get categoriesSavedSnack => 'Category style saved';

  @override
  String get categoriesAddedSnack => 'Category created';

  @override
  String get categoriesAddSub =>
      'Create a custom category (name + color + icon)';

  @override
  String get categoriesImgLabel =>
      'Image icon (replace pin icon with a local image)';

  @override
  String get categoriesImgUpload => 'Upload image';

  @override
  String get categoriesImgReplace => 'Replace image';

  @override
  String get categoriesImgClear => 'Remove image';

  @override
  String get categoriesImgEmpty =>
      'No image · built-in icon selected above is used';

  @override
  String get categoriesImgCurrent =>
      'Uploaded · map pin and other views show this image';

  @override
  String get categoriesImgHint =>
      'Requires a 1:1 square image (up to 512×512); it replaces the pin icon at the same size as built-in icons. Pick a built-in icon or remove the image to revert.';

  @override
  String get categoriesImgNotSquare =>
      'Image must be square (1:1). Please crop it and upload again';

  @override
  String get categoriesImgSaved => 'Image icon saved';

  @override
  String get categoriesImgFail =>
      'Could not read or save the image. Try another one';

  @override
  String categoriesColorHex(String hex) {
    return 'Color #$hex';
  }
}
