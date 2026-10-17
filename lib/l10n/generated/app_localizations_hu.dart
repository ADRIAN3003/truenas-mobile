// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'TrueNAS Mobile';

  @override
  String get serversTitle => 'Szerverek';

  @override
  String get serversEmptyTitle => 'Még nincs szerver';

  @override
  String get serversEmptyBody =>
      'Adj hozzá egy TrueNAS szervert (25.04 vagy újabb), hogy kezelhesd.';

  @override
  String get addServer => 'Szerver hozzáadása';

  @override
  String get editServer => 'Szerver szerkesztése';

  @override
  String get edit => 'Szerkesztés';

  @override
  String get delete => 'Törlés';

  @override
  String get cancel => 'Mégse';

  @override
  String get save => 'Mentés';

  @override
  String get retry => 'Újra';

  @override
  String deleteServerTitle(String name) {
    return 'Törlöd ezt: $name?';
  }

  @override
  String get deleteServerBody =>
      'A szerver csak ebből az alkalmazásból törlődik. Magán a szerveren semmi nem változik.';

  @override
  String get fieldName => 'Név';

  @override
  String get fieldNameHint => 'Otthoni NAS';

  @override
  String get fieldAddress => 'Cím';

  @override
  String get fieldAddressHint => 'nas.local vagy https://192.168.1.10';

  @override
  String get fieldUsername => 'Felhasználónév';

  @override
  String get fieldApiKey => 'API-kulcs';

  @override
  String get fieldApiKeyHelp =>
      'A TrueNAS-ban hozhatsz létre egyet: Credentials > Users > API keys.';

  @override
  String get fieldPassword => 'Jelszó';

  @override
  String get authApiKey => 'API-kulcs';

  @override
  String get authPassword => 'Jelszó';

  @override
  String get validationRequired => 'Kötelező';

  @override
  String get validationAddress => 'Adj meg egy gépnevet vagy egy http(s) címet';

  @override
  String get validationApiKeyHttps =>
      'Az API-kulcsokhoz HTTPS kell. A TrueNAS visszavonja a sima HTTP-n küldött kulcsokat.';

  @override
  String get testConnection => 'Kapcsolat tesztelése';

  @override
  String testSucceeded(String hostname, String version) {
    return 'Kapcsolódva: $hostname (TrueNAS $version)';
  }

  @override
  String get connecting => 'Kapcsolódás…';

  @override
  String get certificateTitle => 'Megbízol ebben a tanúsítványban?';

  @override
  String get certificateChangedTitle => 'Megváltozott a tanúsítvány';

  @override
  String get certificateBody =>
      'A szerver tanúsítványát nem olyan kiadó írta alá, amelyben ez az eszköz megbízik. Ez normális a TrueNAS saját aláírású tanúsítványánál. Csak akkor fogadd el, ha az ujjlenyomat egyezik a TrueNAS-ban látottal (Credentials > Certificates).';

  @override
  String get certificateChangedBody =>
      'A szerver tanúsítványa eltér attól, amelyben korábban megbíztál. Ha nem te cserélted le, lehet, hogy valaki lehallgatja a kapcsolatot.';

  @override
  String get certificateSubject => 'Kiállítva neki';

  @override
  String get certificateIssuer => 'Kiállító';

  @override
  String get certificateExpires => 'Lejár';

  @override
  String get certificateFingerprint => 'SHA-256 ujjlenyomat';

  @override
  String get trust => 'Megbízom benne';

  @override
  String get otpTitle => 'Kétlépcsős kód';

  @override
  String get otpBody => 'Írd be a hitelesítő alkalmazás 6 jegyű kódját.';

  @override
  String get otpSubmit => 'Ellenőrzés';

  @override
  String get errorLoginRejected =>
      'A szerver elutasította a bejelentkezést. Ellenőrizd a felhasználónevet és az API-kulcsot vagy jelszót.';

  @override
  String get errorLoginExpired => 'Az API-kulcs vagy a jelszó lejárt.';

  @override
  String get errorUnsupported =>
      'Ez a szerver túl régi. A TrueNAS Mobile-hoz TrueNAS 25.04 vagy újabb kell.';

  @override
  String get errorCertificate =>
      'A tanúsítványt nem fogadtad el, ezért az alkalmazás nem kapcsolódott.';

  @override
  String errorGeneric(String details) {
    return 'Nem sikerült kapcsolódni: $details';
  }

  @override
  String get infoHostname => 'Gépnév';

  @override
  String get infoVersion => 'TrueNAS verzió';

  @override
  String get infoApiVersion => 'API-verzió';

  @override
  String get infoModel => 'Processzor';

  @override
  String get infoCores => 'Processzormagok';

  @override
  String get infoMemory => 'Memória';

  @override
  String get infoUptime => 'Üzemidő';

  @override
  String get infoSignedInAs => 'Bejelentkezve mint';

  @override
  String get errorCancelled => 'A kapcsolódás megszakítva.';

  @override
  String get tabDashboard => 'Főoldal';

  @override
  String get tabAlerts => 'Riasztások';

  @override
  String get tabJobs => 'Feladatok';

  @override
  String get cpuTitle => 'Processzor';

  @override
  String cpuTemperature(String temp) {
    return '$temp °C';
  }

  @override
  String get memoryTitle => 'Memória';

  @override
  String memoryUsedOf(String used, String total) {
    return '$used / $total használatban';
  }

  @override
  String get memoryServices => 'Szolgáltatások';

  @override
  String get memoryArc => 'ZFS gyorsítótár';

  @override
  String get memoryFree => 'Szabad';

  @override
  String get networkTitle => 'Hálózat';

  @override
  String get networkIn => 'Be';

  @override
  String get networkOut => 'Ki';

  @override
  String get poolsTitle => 'Poolok';

  @override
  String get poolsEmpty => 'Nincs pool';

  @override
  String poolUsage(String used, String total) {
    return '$used / $total';
  }

  @override
  String get alertsTitle => 'Riasztások';

  @override
  String get alertsNone => 'Nincs aktív riasztás';

  @override
  String alertsCritical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kritikus',
    );
    return '$_temp0';
  }

  @override
  String alertsWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count figyelmeztetés',
    );
    return '$_temp0';
  }

  @override
  String alertsInfo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count értesítés',
    );
    return '$_temp0';
  }

  @override
  String get alertsActive => 'Aktív';

  @override
  String get alertsDismissed => 'Elvetett';

  @override
  String get alertDismiss => 'Elvetés';

  @override
  String get alertRestore => 'Visszaállítás';

  @override
  String get levelCritical => 'Kritikus';

  @override
  String get levelWarning => 'Figyelmeztetés';

  @override
  String get levelInfo => 'Információ';

  @override
  String get jobsEmpty => 'Nincs friss feladat';

  @override
  String get jobAbort => 'Megszakítás';

  @override
  String get jobAbortTitle => 'Megszakítod ezt a feladatot?';

  @override
  String get jobStateWaiting => 'Várakozik';

  @override
  String get jobStateRunning => 'Fut';

  @override
  String get jobStateSuccess => 'Sikeres';

  @override
  String get jobStateFailed => 'Sikertelen';

  @override
  String get jobStateAborted => 'Megszakítva';

  @override
  String get close => 'Bezárás';

  @override
  String get liveWaiting => 'Várakozás az élő adatokra…';

  @override
  String get systemTitle => 'Rendszer';

  @override
  String get tabStorage => 'Tárhely';

  @override
  String get disksTitle => 'Lemezek';

  @override
  String get disksSubtitle => 'Állapot, hőmérséklet és pooltagság';

  @override
  String get disksEmpty => 'Nincs lemez';

  @override
  String get diskUnused => 'Nincs poolban';

  @override
  String diskPool(String pool) {
    return 'Pool: $pool';
  }

  @override
  String diskSerial(String serial) {
    return 'Sorozatszám: $serial';
  }

  @override
  String get diskSsd => 'SSD';

  @override
  String diskRpm(int rpm) {
    return '$rpm f/perc';
  }

  @override
  String get scrubTitle => 'Scrub';

  @override
  String scrubRunning(String percent) {
    return 'Scrub fut: $percent%';
  }

  @override
  String resilverRunning(String percent) {
    return 'Resilver fut: $percent%';
  }

  @override
  String scrubPaused(String percent) {
    return 'Scrub szüneteltetve $percent%-nál';
  }

  @override
  String scrubFinished(String date, int errors) {
    String _temp0 = intl.Intl.pluralLogic(
      errors,
      locale: localeName,
      other: '$errors hibával',
      zero: 'hiba nélkül',
    );
    return 'Az utolsó scrub $date fejeződött be, $_temp0';
  }

  @override
  String get scrubCanceled => 'Az utolsó scrub le lett állítva';

  @override
  String get scrubNever => 'Még nem futott scrub';

  @override
  String get scrubStart => 'Scrub indítása';

  @override
  String get scrubPause => 'Szünet';

  @override
  String get scrubResume => 'Folytatás';

  @override
  String get scrubStop => 'Leállítás';

  @override
  String get scrubStarted => 'A scrub elindult';

  @override
  String scrubStopTitle(String pool) {
    return 'Leállítod a scrubot ezen: $pool?';
  }

  @override
  String get scrubStopBody =>
      'Az eddigi haladás elvész, és a következő scrub elölről kezdődik.';

  @override
  String get topologyTitle => 'Felépítés';

  @override
  String get vdevGroupData => 'Adat';

  @override
  String get vdevGroupLog => 'Napló';

  @override
  String get vdevGroupCache => 'Gyorsítótár';

  @override
  String get vdevGroupSpare => 'Tartalék';

  @override
  String get vdevGroupSpecial => 'Metaadat';

  @override
  String get vdevGroupDedup => 'Deduplikáció';

  @override
  String vdevErrors(int read, int write, int checksum) {
    return '$read olvasási, $write írási, $checksum ellenőrzőösszeg-hiba';
  }

  @override
  String poolFree(String free) {
    return '$free szabad';
  }

  @override
  String get datasetsTitle => 'Datasetek';

  @override
  String get datasetsEmpty => 'Nincs dataset';

  @override
  String get datasetCreate => 'Dataset létrehozása';

  @override
  String datasetCreated(String name) {
    return 'Létrehozva: $name';
  }

  @override
  String get datasetParent => 'Szülő';

  @override
  String get datasetNameField => 'Név';

  @override
  String get datasetNameInvalid =>
      'Csak betűk, számok, valamint - _ . és : használható';

  @override
  String get datasetTypeFilesystem => 'Dataset';

  @override
  String get datasetTypeVolume => 'Zvol';

  @override
  String get datasetSizeGib => 'Méret (GiB)';

  @override
  String get datasetSizeInvalid => 'Adj meg 0-nál nagyobb méretet';

  @override
  String get datasetUsed => 'Foglalt';

  @override
  String get datasetAvailable => 'Elérhető';

  @override
  String get datasetCompression => 'Tömörítés';

  @override
  String get datasetCompressRatio => 'Tömörítési arány';

  @override
  String get datasetMountpoint => 'Csatolási pont';

  @override
  String get datasetVolsize => 'Zvol mérete';

  @override
  String get datasetEncryption => 'Titkosítás';

  @override
  String get datasetEncrypted => 'Titkosított';

  @override
  String get datasetLocked => 'Titkosított, zárolva';

  @override
  String get datasetNotEncrypted => 'Nem titkosított';

  @override
  String get datasetZvol => 'Zvol';

  @override
  String get datasetDelete => 'Dataset törlése';

  @override
  String datasetDeleteTitle(String name) {
    return 'Törlöd ezt: $name?';
  }

  @override
  String get datasetDeleteBody =>
      'Ez véglegesen megsemmisíti a datasetet, a gyermek-dataseteket, valamint az összes pillanatképüket és adatukat. Nem vonható vissza.';

  @override
  String typeNameToConfirm(String name) {
    return 'A megerősítéshez írd be: $name';
  }

  @override
  String datasetDeleted(String name) {
    return 'Törölve: $name';
  }

  @override
  String get snapshotsTitle => 'Pillanatképek';

  @override
  String get snapshotsEmpty => 'Nincs pillanatkép';

  @override
  String get snapshotCreate => 'Pillanatkép készítése';

  @override
  String get snapshotNameField => 'Pillanatkép neve';

  @override
  String get snapshotRecursive => 'Gyermek-datasetekkel együtt';

  @override
  String get snapshotCreated => 'Pillanatkép elkészült';

  @override
  String get snapshotDelete => 'Törlés';

  @override
  String snapshotDeleteTitle(String name) {
    return 'Törlöd a(z) $name pillanatképet?';
  }

  @override
  String get snapshotDeleteBody =>
      'A pillanatkép megsemmisül. Az élő dataset adatait ez nem érinti.';

  @override
  String get snapshotDeleted => 'Pillanatkép törölve';

  @override
  String get snapshotRollback => 'Visszaállítás';

  @override
  String snapshotRollbackTitle(String dataset) {
    return 'Visszaállítod ezt: $dataset?';
  }

  @override
  String snapshotRollbackBody(String name) {
    return 'A dataset visszaáll a(z) $name pillanatkép állapotára. Az azóta történt összes változás elvész, és az újabb pillanatképek megsemmisülnek.';
  }

  @override
  String snapshotRolledBack(String name) {
    return 'Visszaállítva erre: $name';
  }

  @override
  String snapshotSize(String used, String referenced) {
    return '$used foglalt · $referenced hivatkozott';
  }

  @override
  String get create => 'Létrehozás';

  @override
  String get tabShares => 'Megosztások';

  @override
  String get servicesTitle => 'Szolgáltatások';

  @override
  String get servicesSubtitle =>
      'Indítás, leállítás és automatikus indulás beállítása';

  @override
  String get servicesEmpty => 'Nincs szolgáltatás';

  @override
  String get serviceRunning => 'Fut';

  @override
  String get serviceStopped => 'Leállítva';

  @override
  String get serviceStart => 'Indítás';

  @override
  String get serviceStop => 'Leállítás';

  @override
  String get serviceRestart => 'Újraindítás';

  @override
  String get serviceStartOnBoot => 'Indulás rendszerindításkor';

  @override
  String serviceStopTitle(String name) {
    return 'Leállítod ezt: $name?';
  }

  @override
  String get serviceStopBody =>
      'A szolgáltatást használó kliensek elvesztik a hozzáférést, amíg újra el nem indítod.';

  @override
  String serviceStartedMessage(String name) {
    return '$name fut';
  }

  @override
  String serviceStoppedMessage(String name) {
    return '$name leállítva';
  }

  @override
  String serviceNotRunning(String name) {
    return 'A(z) $name szolgáltatás le van állítva, ezért ezek a megosztások nem érhetők el.';
  }

  @override
  String get smbTitle => 'SMB-megosztások';

  @override
  String get nfsTitle => 'NFS-megosztások';

  @override
  String sharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count megosztás',
      zero: 'Nincs megosztás',
    );
    return '$_temp0';
  }

  @override
  String get sharesEmpty => 'Még nincs megosztás';

  @override
  String get shareCreate => 'Megosztás hozzáadása';

  @override
  String get shareEdit => 'Megosztás szerkesztése';

  @override
  String get shareName => 'Megosztás neve';

  @override
  String get sharePath => 'Mappa';

  @override
  String get shareComment => 'Leírás';

  @override
  String get shareReadOnly => 'Csak olvasható';

  @override
  String get shareBrowsable => 'Látható a hálózat böngészésekor';

  @override
  String get shareEnabled => 'Engedélyezve';

  @override
  String get shareDisabled => 'Letiltva';

  @override
  String get shareLocked => 'A dataset zárolva';

  @override
  String get shareNoDatasets =>
      'Előbb hozz létre egy datasetet. A megosztás mindig egy dataset mappájára mutat.';

  @override
  String get shareCreated => 'Megosztás hozzáadva';

  @override
  String get shareSaved => 'Megosztás mentve';

  @override
  String get shareDelete => 'Megosztás törlése';

  @override
  String shareDeleteTitle(String name) {
    return 'Törlöd a(z) $name megosztást?';
  }

  @override
  String shareDeleteBody(String path) {
    return 'A kliensek többé nem érik el. A(z) $path mappában lévő fájlok megmaradnak.';
  }

  @override
  String get shareDeleted => 'Megosztás törölve';

  @override
  String get nfsAllowedEveryone => 'Bármely gép csatlakozhat';

  @override
  String nfsAllowed(String list) {
    return 'Engedélyezett: $list';
  }

  @override
  String get iscsiTitle => 'iSCSI';

  @override
  String get iscsiTargets => 'Targetek';

  @override
  String get iscsiExtents => 'Extentek';

  @override
  String iscsiSummary(int targets, int extents) {
    return 'Targetek: $targets · Extentek: $extents';
  }

  @override
  String get iscsiEmpty => 'Nincs iSCSI target';

  @override
  String get nvmetTitle => 'NVMe over Fabrics';

  @override
  String nvmetSummary(int count) {
    return 'Alrendszerek: $count';
  }

  @override
  String get nvmetEmpty => 'Nincs NVMe-oF alrendszer';

  @override
  String get nvmetAnyHost => 'Bármely gép csatlakozhat';

  @override
  String get nvmetAllowedHosts => 'Csak az engedélyezett gépek csatlakozhatnak';

  @override
  String get viewOnlyNote =>
      'Egyelőre csak megtekinthető. A módosításhoz használd a TrueNAS webes felületét.';

  @override
  String get tabApps => 'Appok';

  @override
  String get tabMore => 'Továbbiak';

  @override
  String get appsTitle => 'Alkalmazások';

  @override
  String get appsEmpty => 'Nincs telepített alkalmazás';

  @override
  String get vmsTitle => 'Virtuális gépek';

  @override
  String get vmsEmpty => 'Nincs virtuális gép';

  @override
  String get containersTitle => 'Konténerek';

  @override
  String get containersEmpty => 'Nincs konténer';

  @override
  String get stateRunning => 'Fut';

  @override
  String get stateStopped => 'Leállítva';

  @override
  String get stateDeploying => 'Indul';

  @override
  String get stateStopping => 'Leáll';

  @override
  String get stateSuspended => 'Szüneteltetve';

  @override
  String get stateCrashed => 'Összeomlott';

  @override
  String get stateUnknown => 'Ismeretlen';

  @override
  String get actionStart => 'Indítás';

  @override
  String get actionStop => 'Leállítás';

  @override
  String get actionRestart => 'Újraindítás';

  @override
  String get actionPowerOff => 'Kikapcsolás';

  @override
  String get actionUpgrade => 'Frissítés';

  @override
  String get actionDelete => 'Törlés';

  @override
  String actionStarted(String name) {
    return '$name elindítva';
  }

  @override
  String actionStopped(String name) {
    return '$name leállítva';
  }

  @override
  String actionRestarted(String name) {
    return '$name újraindítva';
  }

  @override
  String actionPoweredOff(String name) {
    return '$name kikapcsolva';
  }

  @override
  String actionUpgraded(String name) {
    return '$name frissítve';
  }

  @override
  String actionDeleted(String name) {
    return '$name törölve';
  }

  @override
  String stopTitle(String name) {
    return 'Leállítod ezt: $name?';
  }

  @override
  String get stopBody => 'Nem érhető el, amíg újra el nem indítod.';

  @override
  String get vmStopBody =>
      'A vendégrendszer leállítási kérést kap. Ha a leállítási időkorláton belül nem áll le, kikapcsoljuk.';

  @override
  String restartTitle(String name) {
    return 'Újraindítod ezt: $name?';
  }

  @override
  String get restartBody =>
      'Az újraindítás alatt egy pillanatig nem érhető el.';

  @override
  String vmPowerOffTitle(String name) {
    return 'Kikapcsolod ezt: $name?';
  }

  @override
  String get vmPowerOffBody =>
      'Ez azonnal megszakítja az áramellátást, mintha kihúznád a dugót. A VM-ben lévő mentetlen munka elveszhet.';

  @override
  String appUpgradeTitle(String name) {
    return 'Frissíted ezt: $name?';
  }

  @override
  String appUpgradeBody(String name, String from, String to) {
    return '$name: $from → $to. Az alkalmazás a frissítés közben újraindul.';
  }

  @override
  String appDeleteTitle(String name) {
    return 'Törlöd ezt: $name?';
  }

  @override
  String get appDeleteBody =>
      'Az alkalmazás, a konténerei és a képfájljai törlődnek. A köteteiben és a gazdagép mappáiban lévő adatok megmaradnak.';

  @override
  String get appUpdateAvailable => 'Frissítés érhető el';

  @override
  String get appImageUpdates => 'Újabb képfájlok érhetők el';

  @override
  String get appVersion => 'Verzió';

  @override
  String get appLatestVersion => 'Legújabb verzió';

  @override
  String get appContainersRunning => 'Futó konténerek';

  @override
  String get appImages => 'Képfájlok';

  @override
  String get appPortals => 'Webes felületek';

  @override
  String get appCustom => 'Egyéni alkalmazás';

  @override
  String get appNotes => 'Jegyzetek';

  @override
  String vmSummary(int vcpus, String memory) {
    return '$vcpus vCPU · $memory';
  }

  @override
  String get vmAutostart => 'Rendszerindításkor elindul';

  @override
  String get containerIsVm => 'Incus VM';

  @override
  String get copied => 'Másolva';

  @override
  String get moreAccounts => 'Fiókok';

  @override
  String get moreSystem => 'Rendszer';

  @override
  String get moreActivity => 'Tevékenység';

  @override
  String get usersTitle => 'Felhasználók';

  @override
  String get usersEmpty =>
      'Még nincs felhasználó. A rendszerfiókok rejtve vannak.';

  @override
  String get usersShowBuiltin => 'Rendszerfiókok megjelenítése';

  @override
  String get userCreate => 'Felhasználó hozzáadása';

  @override
  String get userUsername => 'Felhasználónév';

  @override
  String get userFullName => 'Teljes név';

  @override
  String get userPassword => 'Jelszó';

  @override
  String get userSmb => 'SMB-hozzáférés engedélyezése';

  @override
  String get userUsernameInvalid =>
      'Kisbetűk, számjegyek, - vagy _ használható, betűvel kezdve';

  @override
  String get userPasswordRequired => 'Adj meg egy jelszót';

  @override
  String userCreated(String name) {
    return 'Hozzáadva: $name';
  }

  @override
  String get userLocked => 'Zárolva';

  @override
  String get userBuiltin => 'Rendszer';

  @override
  String get userLock => 'Zárolás';

  @override
  String get userUnlock => 'Feloldás';

  @override
  String userLockedMessage(String name) {
    return 'Zárolva: $name';
  }

  @override
  String userUnlockedMessage(String name) {
    return 'Feloldva: $name';
  }

  @override
  String userDeleteTitle(String name) {
    return 'Törlöd a(z) $name felhasználót?';
  }

  @override
  String get userDeleteBody =>
      'A fiók és a saját csoportja törlődik. A tulajdonában lévő fájlok a lemezen maradnak.';

  @override
  String userDeleted(String name) {
    return 'Törölve: $name';
  }

  @override
  String get userTwoFactor => 'Kétlépcsős azonosítás';

  @override
  String get groupsTitle => 'Csoportok';

  @override
  String get groupsEmpty =>
      'Még nincs csoport. A rendszercsoportok rejtve vannak.';

  @override
  String get groupCreate => 'Csoport hozzáadása';

  @override
  String get groupName => 'Csoport neve';

  @override
  String groupCreated(String name) {
    return 'Hozzáadva: $name';
  }

  @override
  String groupDeleteTitle(String name) {
    return 'Törlöd a(z) $name csoportot?';
  }

  @override
  String get groupDeleteBody => 'A tagok fiókjai megmaradnak.';

  @override
  String groupDeleted(String name) {
    return 'Törölve: $name';
  }

  @override
  String get apiKeysTitle => 'API-kulcsok';

  @override
  String get apiKeysEmpty => 'Még nincs API-kulcs.';

  @override
  String get apiKeyCreate => 'API-kulcs hozzáadása';

  @override
  String get apiKeyName => 'Kulcs neve';

  @override
  String get apiKeyUser => 'Felhasználó';

  @override
  String get apiKeyCreatedTitle => 'Másold ki az API-kulcsot';

  @override
  String get apiKeyCreatedBody =>
      'A kulcs csak most jelenik meg. Tárold biztonságos helyen.';

  @override
  String get apiKeyCopied => 'Vágólapra másolva';

  @override
  String get apiKeyRevoked => 'Visszavonva';

  @override
  String apiKeyExpires(String date) {
    return 'Lejár: $date';
  }

  @override
  String apiKeyCreatedOn(String date) {
    return 'Létrehozva: $date';
  }

  @override
  String apiKeyDeleteTitle(String name) {
    return 'Törlöd a(z) $name API-kulcsot?';
  }

  @override
  String get apiKeyDeleteBody =>
      'Minden, ami ezt a kulcsot használja, elveszti a hozzáférést.';

  @override
  String apiKeyDeleted(String name) {
    return 'Törölve: $name';
  }

  @override
  String get copy => 'Másolás';

  @override
  String get done => 'Kész';

  @override
  String get networkHostname => 'Gépnév';

  @override
  String get networkGateway => 'Alapértelmezett átjáró';

  @override
  String get networkDns => 'DNS-szerverek';

  @override
  String get networkInterfaces => 'Interfészek';

  @override
  String get networkLinkUp => 'Kapcsolat él';

  @override
  String get networkLinkDown => 'Nincs kapcsolat';

  @override
  String get networkDhcp => 'DHCP';

  @override
  String get networkNone => 'Nincs';

  @override
  String get certificatesTitle => 'Tanúsítványok';

  @override
  String get certificatesEmpty => 'Nincs tanúsítvány.';

  @override
  String get certificateExpired => 'Lejárt';

  @override
  String certificateValidUntil(String date) {
    return 'Érvényes eddig: $date';
  }

  @override
  String get updatesTitle => 'Frissítések';

  @override
  String updateCurrent(String version) {
    return 'Jelenlegi verzió: $version';
  }

  @override
  String updateAvailable(String version) {
    return 'Elérhető: $version';
  }

  @override
  String get updateNone => 'A TrueNAS naprakész';

  @override
  String get updateRebootRequired =>
      'Egy frissítés telepítve. A befejezéshez indítsd újra.';

  @override
  String updateCheckFailed(String reason) {
    return 'Nem sikerült ellenőrizni a frissítéseket: $reason';
  }

  @override
  String get updateInstall => 'Telepítés és újraindítás';

  @override
  String updateInstallTitle(String version) {
    return 'Telepíted ezt: $version?';
  }

  @override
  String get updateInstallBody =>
      'A szerver letölti és telepíti a frissítést, majd újraindul. Az újraindítás alatt nem érhető el.';

  @override
  String get updateStarted =>
      'A frissítés elindult. A szerver a végén újraindul.';

  @override
  String get updateReleaseNotes => 'Kiadási megjegyzések';

  @override
  String get bootEnvsTitle => 'Boot környezetek';

  @override
  String get bootEnvActive => 'Jelenleg fut';

  @override
  String get bootEnvNextBoot => 'Következő indításkor';

  @override
  String get bootEnvKept => 'Megtartva';

  @override
  String get bootEnvActivate => 'Használat következő indításkor';

  @override
  String bootEnvActivateTitle(String name) {
    return 'Következő indításkor ezt használja: $name?';
  }

  @override
  String get bootEnvActivateBody =>
      'A szerver a következő újraindítás után ezt a verziót használja.';

  @override
  String get bootEnvKeep => 'Megtartás';

  @override
  String get bootEnvUnkeep => 'Megtartás megszüntetése';

  @override
  String bootEnvDeleteTitle(String name) {
    return 'Törlöd a(z) $name boot környezetet?';
  }

  @override
  String get bootEnvDeleteBody => 'Utána nem térhetsz vissza erre a verzióra.';

  @override
  String get bootEnvChanged => 'Boot környezet frissítve';

  @override
  String get powerReboot => 'Szerver újraindítása';

  @override
  String get powerShutdown => 'Szerver leállítása';

  @override
  String powerRebootTitle(String name) {
    return 'Újraindítod ezt: $name?';
  }

  @override
  String powerShutdownTitle(String name) {
    return 'Leállítod ezt: $name?';
  }

  @override
  String get powerRebootBody =>
      'A szerveren minden, a megosztásokat, alkalmazásokat és VM-eket is beleértve, leáll, amíg vissza nem tér.';

  @override
  String get powerShutdownBody =>
      'A szerveren minden leáll. Az újbóli bekapcsoláshoz fizikai vagy távoli konzolos hozzáférés kell.';

  @override
  String powerRebooting(String name) {
    return '$name újraindul';
  }

  @override
  String powerShuttingDown(String name) {
    return '$name leáll';
  }

  @override
  String get restart => 'Újraindítás';

  @override
  String get shutDown => 'Leállítás';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tag',
      zero: 'Nincs tag',
    );
    return '$_temp0';
  }

  @override
  String get moreTools => 'Eszközök';

  @override
  String get explorerTitle => 'API-böngésző';

  @override
  String get explorerSearch => 'Metódusok keresése';

  @override
  String get explorerNoMatches => 'Nincs találat.';

  @override
  String explorerMethodCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count metódus',
    );
    return '$_temp0';
  }

  @override
  String get explorerJob => 'Feladat';

  @override
  String get explorerReadOnly => 'Csak olvasás';

  @override
  String get explorerNoAuth => 'Nem kell bejelentkezni';

  @override
  String explorerRoles(String roles) {
    return 'Szerepkörök: $roles';
  }

  @override
  String get explorerParameters => 'Paraméterek';

  @override
  String get explorerNoParameters =>
      'Ennek a metódusnak nincsenek paraméterei.';

  @override
  String get explorerSendParam => 'Küldés';

  @override
  String get explorerOptional => 'opcionális';

  @override
  String explorerInvalidJson(String reason) {
    return 'Érvénytelen JSON: $reason';
  }

  @override
  String get explorerInvalidNumber => 'Adj meg egy számot';

  @override
  String get explorerRun => 'Futtatás';

  @override
  String explorerRunTitle(String method) {
    return 'Futtatod ezt: $method?';
  }

  @override
  String get explorerRunBody =>
      'Ez a metódus módosíthat beállításokat vagy adatokat a szerveren.';

  @override
  String get explorerResult => 'Eredmény';

  @override
  String explorerJobRunning(int id) {
    return 'Fut a(z) $id. feladatként…';
  }

  @override
  String get explorerReturns => 'Visszatérési érték';

  @override
  String get explorerFileTransfer =>
      'Ez a metódus fájlt visz át, amire a böngésző még nem képes.';

  @override
  String get explorerCopied => 'Vágólapra másolva';

  @override
  String get explorerUnset => 'Nincs megadva';

  @override
  String get shellTitle => 'Shell';

  @override
  String get shellConnecting => 'Shell megnyitása…';

  @override
  String get shellClosed => 'A shell véget ért.';

  @override
  String get shellReconnect => 'Új shell indítása';

  @override
  String get shellKeyCtrlC => 'Ctrl+C';

  @override
  String get shellKeyEsc => 'Esc';

  @override
  String get shellKeyTab => 'Tab';

  @override
  String get protectionTitle => 'Adatvédelem';

  @override
  String get protectionEmpty => 'Még nincs feladat.';

  @override
  String get protectionSnapshots => 'Időszakos pillanatképek';

  @override
  String get protectionReplication => 'Replikáció';

  @override
  String get protectionCloudSync => 'Felhőszinkronizálás';

  @override
  String get protectionCloudBackup => 'TrueCloud mentés';

  @override
  String get protectionRsync => 'Rsync';

  @override
  String get taskNever => 'Még nem futott';

  @override
  String get taskWaiting => 'Várakozik';

  @override
  String get taskRunning => 'Fut';

  @override
  String taskRunningPercent(int percent) {
    return 'Fut · $percent%';
  }

  @override
  String get taskSuccess => 'Sikeres';

  @override
  String get taskFailed => 'Sikertelen';

  @override
  String get taskHeld => 'Felfüggesztve';

  @override
  String taskLastRun(String date) {
    return 'Utoljára futott: $date';
  }

  @override
  String get taskEnabled => 'Engedélyezve';

  @override
  String get taskRunNow => 'Futtatás most';

  @override
  String get taskStop => 'Leállítás';

  @override
  String taskStarted(String name) {
    return 'Elindítva: $name';
  }

  @override
  String taskStopped(String name) {
    return 'Leállítva: $name';
  }

  @override
  String taskEnabledMessage(String name) {
    return 'Engedélyezve: $name';
  }

  @override
  String taskDisabledMessage(String name) {
    return 'Letiltva: $name';
  }

  @override
  String taskDeleteTitle(String name) {
    return 'Törlöd a(z) $name feladatát?';
  }

  @override
  String get taskDeleteBody => 'A már elkészült pillanatképek megmaradnak.';

  @override
  String get taskDeleted => 'Feladat törölve';

  @override
  String get snapshotTaskCreate => 'Pillanatkép-feladat hozzáadása';

  @override
  String snapshotTaskCreated(String name) {
    return 'Pillanatkép-feladat hozzáadva ehhez: $name';
  }

  @override
  String get snapshotTaskDataset => 'Dataset';

  @override
  String get snapshotTaskRecursive => 'Gyermek-datasetekkel együtt';

  @override
  String get snapshotTaskSchedule => 'Gyakoriság';

  @override
  String get snapshotTaskKeepFor => 'Megőrzés';

  @override
  String get scheduleHourly => 'Óránként';

  @override
  String get scheduleDaily => 'Minden nap éjfélkor';

  @override
  String get scheduleWeekly => 'Minden vasárnap éjfélkor';

  @override
  String scheduleCustom(String cron) {
    return 'Cron: $cron';
  }

  @override
  String get snapshotTaskRecursiveLabel => 'gyermek-datasetekkel';

  @override
  String keepHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Megőrzés: $count óra',
    );
    return '$_temp0';
  }

  @override
  String keepDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Megőrzés: $count nap',
    );
    return '$_temp0';
  }

  @override
  String keepWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Megőrzés: $count hét',
    );
    return '$_temp0';
  }

  @override
  String keepMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Megőrzés: $count hónap',
    );
    return '$_temp0';
  }

  @override
  String keepYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Megőrzés: $count év',
    );
    return '$_temp0';
  }

  @override
  String get unitHours => 'Óra';

  @override
  String get unitDays => 'Nap';

  @override
  String get unitWeeks => 'Hét';

  @override
  String get unitMonths => 'Hónap';

  @override
  String get unitYears => 'Év';

  @override
  String get protectionSubtitle =>
      'Pillanatkép-feladatok, replikáció és felhőszinkronizálás';

  @override
  String get protectionAdd => 'Feladat hozzáadása';

  @override
  String get taskDeleteBodyCopies => 'A már átmásolt adatok megmaradnak.';

  @override
  String taskSaved(String name) {
    return 'Mentve: $name';
  }

  @override
  String get replicationNew => 'Új replikációs feladat';

  @override
  String get replicationEdit => 'Replikációs feladat szerkesztése';

  @override
  String get cloudSyncNew => 'Új felhőszinkronizálási feladat';

  @override
  String get cloudSyncEdit => 'Felhőszinkronizálási feladat szerkesztése';

  @override
  String get taskNameLabel => 'Név';

  @override
  String get directionLabel => 'Irány';

  @override
  String get replicationPush => 'Küldés: erről a szerverről';

  @override
  String get replicationPull => 'Lekérés: egy másik szerverről';

  @override
  String get replicationTransport => 'Cél';

  @override
  String get transportLocal => 'Egy másik pool ezen a szerveren';

  @override
  String get transportSsh => 'Egy másik szerver SSH-n keresztül';

  @override
  String get transportNetcat => 'Egy másik szerver SSH-n és netcaten keresztül';

  @override
  String get replicationSshConnection => 'SSH-kapcsolat';

  @override
  String get replicationNoSshConnections =>
      'Még nincs SSH-kapcsolat. Adj hozzá egyet a TrueNAS webes felületén a Credentials alatt.';

  @override
  String get replicationSources => 'Forrás-datasetek';

  @override
  String get replicationSourcesHint => 'Többet vesszővel válassz el';

  @override
  String get replicationTarget => 'Cél-dataset';

  @override
  String get pickDataset => 'Válassz datasetet';

  @override
  String get replicationSnapshotTasks => 'Ezek pillanatképeinek küldése';

  @override
  String get replicationNoSnapshotTasks =>
      'Nincs időszakos pillanatkép-feladat. A pillanatképek név alapján lesznek kiválasztva.';

  @override
  String get replicationNamingSchema => 'Pillanatképnév-minta';

  @override
  String get replicationNamingSchemaHint => 'Például auto-%Y-%m-%d_%H-%M';

  @override
  String replicationNameRegex(String regex) {
    return 'A pillanatképek a(z) $regex minta alapján választódnak ki. Ezt a TrueNAS webes felületén módosíthatod.';
  }

  @override
  String get replicationAuto => 'Automatikus futtatás';

  @override
  String get replicationAfterSnapshots =>
      'Közvetlenül a pillanatkép-feladat után';

  @override
  String get replicationRetention => 'Pillanatképek megőrzése a célon';

  @override
  String get retentionSource => 'Ugyanúgy, mint a forráson';

  @override
  String get retentionCustom => 'Megadott ideig';

  @override
  String get retentionNone => 'Örökre';

  @override
  String get cloudSyncDescription => 'Leírás';

  @override
  String get cloudSyncCredential => 'Felhő-hitelesítő adat';

  @override
  String get cloudSyncNoCredentials =>
      'Még nincs felhő-hitelesítő adat. Adj hozzá egyet a TrueNAS webes felületén a Credentials alatt.';

  @override
  String get cloudSyncBucket => 'Bucket';

  @override
  String get cloudSyncBucketHint =>
      'Hagyd üresen bucket nélküli szolgáltatóknál';

  @override
  String get cloudSyncFolder => 'Távoli mappa';

  @override
  String get cloudSyncPath => 'Helyi mappa';

  @override
  String get cloudSyncPathHint => 'Egy /mnt alatti mappa';

  @override
  String get cloudSyncPathInvalid => 'Válassz egy /mnt alatti mappát';

  @override
  String get cloudSyncPush => 'Küldés: feltöltés a felhőbe';

  @override
  String get cloudSyncPull => 'Lekérés: letöltés a felhőből';

  @override
  String get transferModeLabel => 'Átviteli mód';

  @override
  String get transferCopy => 'Új és módosult fájlok másolása';

  @override
  String get transferSync => 'Tükrözés, a forrásból hiányzó fájlok törlésével';

  @override
  String get transferMove => 'Áthelyezés, a fájlok törlésével a forrásból';

  @override
  String get showSecret => 'Megjelenítés';

  @override
  String get hideSecret => 'Elrejtés';

  @override
  String get clearSearch => 'Keresés törlése';

  @override
  String get shellKeyUp => 'Fel nyíl';

  @override
  String get shellKeyDown => 'Le nyíl';

  @override
  String get shellKeyLeft => 'Bal nyíl';

  @override
  String get shellKeyRight => 'Jobb nyíl';

  @override
  String get shellNoContainers =>
      'Ennek az alkalmazásnak nincs futó konténere, amiben shellt lehetne nyitni.';

  @override
  String get shellPickContainer => 'Shell megnyitása itt';

  @override
  String get rsyncNew => 'Új rsync feladat';

  @override
  String get rsyncEdit => 'Rsync feladat szerkesztése';

  @override
  String get rsyncUser => 'Futtató felhasználó';

  @override
  String get rsyncUserHint =>
      'Helyi felhasználó; mentett kapcsolat nélküli SSH esetén saját SSH-kulcs kell neki';

  @override
  String get rsyncPush => 'Küldés: másolás a távoli gépre';

  @override
  String get rsyncPull => 'Lekérés: másolás a távoli gépről';

  @override
  String get rsyncMode => 'Kapcsolódás módja';

  @override
  String get rsyncModeSsh => 'SSH';

  @override
  String get rsyncModeModule => 'Rsync démon modul';

  @override
  String get rsyncManualHost => 'Gép megadása kézzel';

  @override
  String get rsyncHost => 'Távoli gép';

  @override
  String get rsyncPort => 'SSH-port';

  @override
  String get rsyncModule => 'Modul neve';

  @override
  String get rsyncRemotePath => 'Távoli útvonal';

  @override
  String get rsyncDelete => 'A forrásból hiányzó fájlok törlése';

  @override
  String get cloudBackupNew => 'Új TrueCloud mentési feladat';

  @override
  String get cloudBackupEdit => 'TrueCloud mentési feladat szerkesztése';

  @override
  String get cloudBackupPassword => 'Tároló jelszava';

  @override
  String get cloudBackupPasswordHint =>
      'Ez titkosítja a mentéseket. Őrizd meg: nélküle nem állíthatók vissza.';

  @override
  String get cloudBackupPasswordKeep =>
      'Hagyd üresen a jelenlegi jelszó megtartásához';

  @override
  String get cloudBackupKeepLast => 'Megőrzött mentések száma';

  @override
  String get dashboardConnected => 'Csatlakozva';

  @override
  String get fieldPasswordKeep =>
      'Hagyd üresen a mentett jelszó megtartásához, vagy írj be egy újat a lecseréléséhez.';

  @override
  String get fieldApiKeyKeep =>
      'Hagyd üresen a mentett API-kulcs megtartásához, vagy illessz be egy újat a lecseréléséhez.';

  @override
  String get tabSharesShort => 'Megosztás';

  @override
  String shellFallback(String shell) {
    return 'Ez a shell nincs a konténerben. Helyette ezt próbálom: $shell.';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count szerver',
      one: '1 szerver',
    );
    return '$_temp0';
  }

  @override
  String get shellPaste => 'Beillesztés';

  @override
  String get shellCopied => 'Vágólapra másolva';

  @override
  String leaveServerTitle(String name) {
    return 'Lecsatlakozol erről: $name?';
  }

  @override
  String get leaveServerBody =>
      'Visszalépsz a szerverekhez, és ez a kapcsolat bezárul, vele együtt a rajta nyitott shellek és képernyők is.';

  @override
  String get leaveServerConfirm => 'Lecsatlakozás';

  @override
  String get leaveServerStay => 'Maradok';

  @override
  String get settingsTitle => 'Alkalmazás beállításai';

  @override
  String get settingsAppearance => 'Megjelenés';

  @override
  String get settingsTheme => 'Téma';

  @override
  String get settingsSystemDefault => 'Mint az eszköz';

  @override
  String get themeLight => 'Világos';

  @override
  String get themeDark => 'Sötét';

  @override
  String get settingsLanguage => 'Nyelv';

  @override
  String get settingsGeneral => 'Általános';

  @override
  String get settingsHaptics => 'Rezgő visszajelzés';

  @override
  String get settingsHapticsHint =>
      'Apró rezgések frissítéskor, fülváltáskor és megerősítéskor';

  @override
  String get settingsConfirmLeave => 'Rákérdezés bezárás előtt';

  @override
  String get settingsConfirmLeaveHint =>
      'Megerősítést kér, mielőtt kilépsz egy megnyitott szerverből vagy shellből';

  @override
  String get settingsShell => 'Shell';

  @override
  String get settingsShellFontSize => 'Betűméret';

  @override
  String get settingsShellKeys => 'Extra billentyűk';

  @override
  String get settingsShellKeysHint =>
      'Esc, Tab, Ctrl+C és nyilak a terminál alatt';

  @override
  String get settingsNotifications => 'Értesítések';

  @override
  String get settingsAlertNotifications => 'Riasztási értesítések';

  @override
  String get settingsAlertNotificationsHintIos =>
      'A háttérben ellenőrzi a szervereidet, és értesít az új riasztásokról. Az iOS dönti el, mikor fut az ellenőrzés, ezért késhet, és leáll, ha kisöpröd az appot.';

  @override
  String get settingsAlertNotificationsHintAndroid =>
      'A háttérben kb. 15 percenként ellenőrzi a szervereidet, és értesít az új riasztásokról.';

  @override
  String get settingsAlertKinds => 'Riasztástípusok';

  @override
  String settingsAlertKindsMuted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ki',
      zero: 'Mind be',
    );
    return '$_temp0';
  }

  @override
  String get alertKindsTitle => 'Riasztástípusok';

  @override
  String get alertKindsHint =>
      'Kapcsold ki azokat a riasztástípusokat, amikről nem kérsz értesítést. A Riasztások listában továbbra is látszanak.';

  @override
  String get alertKindsEmpty =>
      'A riasztástípusok egy szerver első háttérellenőrzése után jelennek meg itt.';

  @override
  String get alertKindsSearch => 'Keresés';

  @override
  String get alertKindsOther => 'Egyéb';

  @override
  String get alertMuteKind => 'Ne értesítsen erről a típusról';

  @override
  String get alertUnmuteKind => 'Értesítsen újra erről a típusról';

  @override
  String alertKindMuted(String kind) {
    return 'Nincs több értesítés ebből: \"$kind\"';
  }

  @override
  String alertKindUnmuted(String kind) {
    return 'Újra értesítést kapsz ebből: \"$kind\"';
  }

  @override
  String get settingsAlertLevel => 'Értesítés ettől';

  @override
  String get settingsAlertLevelCritical => 'Kritikus riasztások';

  @override
  String get settingsAlertLevelWarning => 'Figyelmeztetések és kritikusak';

  @override
  String get settingsAlertPermissionDenied =>
      'Az értesítések ki vannak kapcsolva ennél az appnál. Először engedélyezd őket a telefon beállításaiban.';

  @override
  String get settingsAlertScheduleFailed =>
      'A telefon nem indította el a háttérellenőrzést. Próbáld újra egy pillanat múlva.';

  @override
  String get alertNotificationChannel => 'Riasztások';

  @override
  String get alertNotificationChannelDescription =>
      'Új riasztások a TrueNAS szervereidről';

  @override
  String alertNotificationMany(int count) {
    return '$count új riasztás';
  }

  @override
  String get settingsSecurity => 'Biztonság';

  @override
  String get settingsAppLock => 'Alkalmazászár';

  @override
  String get settingsAppLockHintFace =>
      'Face ID-t vagy az eszköz kódját kéri az app megnyitásakor és a háttérből való visszatéréskor.';

  @override
  String get settingsAppLockHintFingerprint =>
      'Ujjlenyomatot vagy az eszköz kódját kéri az app megnyitásakor és a háttérből való visszatéréskor.';

  @override
  String get settingsAppLockHintOther =>
      'Biometrikus azonosítást vagy az eszköz kódját kéri az app megnyitásakor és a háttérből való visszatéréskor.';

  @override
  String get appLockReason => 'A TrueNAS Mobile feloldása';

  @override
  String get appLockChangeReason =>
      'Erősítsd meg, hogy te vagy az, az alkalmazászár módosításához';

  @override
  String get appLockTitle => 'A TrueNAS Mobile zárolva van';

  @override
  String get appLockFailed => 'Nem sikerült a feloldás. Próbáld újra.';

  @override
  String get appLockUnlock => 'Feloldás';

  @override
  String get settingsCertificates => 'Megbízható tanúsítványok';

  @override
  String get settingsCertificatesEmpty =>
      'Nincs megbízhatónak jelölt tanúsítvány. Az önaláírt tanúsítvány, amelyet egy szerverhez elfogadsz, itt fog megjelenni.';

  @override
  String get settingsCertificateForget => 'Elfelejtés';

  @override
  String settingsCertificateForgetTitle(String name) {
    return 'Elfeledteted ennek a tanúsítványát: $name?';
  }

  @override
  String get settingsCertificateForgetBody =>
      'A következő csatlakozáskor újra megkérdezzük, megbízol-e benne.';

  @override
  String get settingsAbout => 'Névjegy';

  @override
  String get settingsVersion => 'Verzió';

  @override
  String get settingsLicences => 'Nyílt forráskódú licencek';

  @override
  String get settingsSource => 'Forráskód';

  @override
  String get shellLeaveTitle => 'Bezárod a shellt?';

  @override
  String get shellLeaveBody => 'Ami benne fut, az leáll.';

  @override
  String get shellLeaveConfirm => 'Shell bezárása';

  @override
  String get settingsUpdates => 'Frissítések';

  @override
  String get settingsCheckUpdates => 'Keresés induláskor';

  @override
  String get settingsCheckUpdatesHint =>
      'Induláskor megnézi a GitHubon, van-e újabb kiadás. Mást nem küld el.';

  @override
  String get settingsCheckNow => 'Frissítések keresése';

  @override
  String get settingsReleaseNotes => 'Kiadási megjegyzések';

  @override
  String get appUpdateTitle => 'Szoftverfrissítés';

  @override
  String get appUpdateChecking => 'Frissítések keresése…';

  @override
  String get appUpdateUpToDateTitle => 'A legfrissebb verziót használod';

  @override
  String appUpdateUpToDateBody(String version) {
    return 'A TrueNAS Mobile $version a legújabb kiadás.';
  }

  @override
  String get appUpdateNoReleases => 'Még nem jelent meg kiadás.';

  @override
  String appUpdateAvailableTitle(String version) {
    return 'Elérhető a $version verzió';
  }

  @override
  String appUpdateAvailableBody(String current) {
    return 'Jelenleg a $current verzió van telepítve.';
  }

  @override
  String appUpdateReleased(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Megjelent: $dateString';
  }

  @override
  String get appUpdateDownload => 'Letöltés és telepítés';

  @override
  String get appUpdateOpenRelease => 'Kiadás oldalának megnyitása';

  @override
  String get appUpdateViewOnGitHub => 'Megnyitás a GitHubon';

  @override
  String get appUpdateSkip => 'Verzió kihagyása';

  @override
  String get appUpdateSkippedNote =>
      'Kihagytad ezt a verziót, ezért induláskor nem ajánljuk fel.';

  @override
  String get appUpdateUnskip => 'Mégsem hagyom ki';

  @override
  String get appUpdateLater => 'Később';

  @override
  String get appUpdateViewUpdate => 'Részletek';

  @override
  String get appUpdatePromptTitle => 'Frissítés érhető el';

  @override
  String appUpdatePromptBody(String version, String current) {
    return 'Elérhető a $version verzió. Jelenleg a $current van telepítve.';
  }

  @override
  String get appUpdateDownloading => 'Letöltés…';

  @override
  String appUpdateDownloadingPercent(int percent) {
    return 'Letöltés… $percent%';
  }

  @override
  String get appUpdateInstalling => 'A telepítő megnyitása…';

  @override
  String get appUpdateWhatsNew => 'Újdonságok';

  @override
  String get appUpdateNoNotes => 'Ehhez a kiadáshoz nincs leírás.';

  @override
  String get appUpdateAllNotes => 'Minden kiadási megjegyzés';

  @override
  String get appUpdateCheckFailed =>
      'Nem sikerült frissítést keresni. Ellenőrizd a kapcsolatot, és próbáld újra.';

  @override
  String get appUpdateRateLimited =>
      'A GitHub korlátozza a kéréseket erről a hálózatról. Próbáld később.';

  @override
  String get appUpdateErrNoApk =>
      'Ehhez a kiadáshoz nincs a telefonodnak megfelelő APK. Nyisd meg a kiadás oldalát, és onnan töltsd le.';

  @override
  String get appUpdateErrDownload =>
      'A letöltés nem sikerült. Ellenőrizd a kapcsolatot, és próbáld újra.';

  @override
  String get appUpdateErrDamaged => 'A letöltött fájl sérült. Próbáld újra.';

  @override
  String get appUpdateErrInstall => 'Nem sikerült megnyitni a telepítőt.';

  @override
  String get appUpdatePermissionTitle =>
      'Frissítések telepítésének engedélyezése';

  @override
  String get appUpdatePermissionBody =>
      'Az Android engedélyt kér, mielőtt egy app frissítést telepíthet. Nyisd meg a beállításokat, engedélyezd a TrueNAS Mobile számára, majd térj vissza, és koppints újra a Letöltés és telepítés gombra.';

  @override
  String get appUpdateOpenSettings => 'Beállítások megnyitása';

  @override
  String appsUpdatesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alkalmazáshoz van frissítés',
    );
    return '$_temp0';
  }

  @override
  String get appsUpdateAll => 'Összes frissítése';

  @override
  String appsUpdateAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alkalmazás frissítése?',
    );
    return '$_temp0';
  }

  @override
  String get appsUpdateAllBody =>
      'A TrueNAS maga frissíti ezeket az alkalmazásokat egymás után, és mindegyik újraindul a frissítés közben. Akkor is folytatja, ha bezárod az alkalmazást.';

  @override
  String get appsUpdateAllLeave =>
      'A TrueNAS akkor is folytatja, ha elhagyod ezt a képernyőt vagy bezárod az alkalmazást.';

  @override
  String appsBulkRunning(String action, int done, int total) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'Frissítés',
      'start': 'Indítás',
      'stop': 'Leállítás',
      'restart': 'Újraindítás',
      'other': 'Művelet',
    });
    return '$_temp0 a szerveren: $done/$total kész';
  }

  @override
  String appsBulkRunningNoCount(String action, int total) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'Frissítés',
      'start': 'Indítás',
      'stop': 'Leállítás',
      'restart': 'Újraindítás',
      'other': 'Művelet',
    });
    return '$_temp0 a szerveren: $total alkalmazás';
  }

  @override
  String appsBulkDone(int count, String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'frissítve',
      'start': 'elindítva',
      'stop': 'leállítva',
      'restart': 'újraindítva',
      'other': 'kész',
    });
    return '$count alkalmazás $_temp0';
  }

  @override
  String appsBulkPartial(int done, int total, String failed, String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'frissítve',
      'start': 'elindítva',
      'stop': 'leállítva',
      'restart': 'újraindítva',
      'other': 'kész',
    });
    String _temp1 = intl.Intl.selectLogic(action, {
      'upgrade': 'Nem frissült',
      'start': 'Nem indult el',
      'stop': 'Nem állt le',
      'restart': 'Nem indult újra',
      'other': 'Sikertelen',
    });
    return '$done/$total alkalmazás $_temp0. $_temp1: $failed';
  }

  @override
  String get appsSelect => 'Kijelölés';

  @override
  String get appsSelectAll => 'Mind kijelölése';

  @override
  String appsSelectedCount(int count) {
    return '$count kijelölve';
  }

  @override
  String get appsBulkUpdate => 'Frissítés';

  @override
  String appsBulkStopTitle(int count) {
    return '$count alkalmazás leállítása?';
  }

  @override
  String get appsBulkStopBody =>
      'Nem érhetők el, amíg újra el nem indítod őket.';

  @override
  String appsBulkRestartTitle(int count) {
    return '$count alkalmazás újraindítása?';
  }

  @override
  String get appsBulkRestartBody =>
      'Az újraindítás alatt egy pillanatig nem érhetők el.';

  @override
  String get settingsLanguageSystemHint =>
      'Megnyitja az alkalmazás nyelvi oldalát a telefon beállításaiban';

  @override
  String get settingsLanguageOpenFailed =>
      'Nem sikerült megnyitni a telefon beállításait.';

  @override
  String get settingsStartup => 'Indításkor';

  @override
  String get settingsDefaultServer => 'Alapértelmezett szerver';

  @override
  String get settingsDefaultServerNone =>
      'Egyik sem, a szerverlista jelenik meg';

  @override
  String get serverDefaultBadge => 'Alapértelmezett';

  @override
  String get settingsLiveJobs => 'Élő feladatkövetés';

  @override
  String get settingsLiveJobsHint =>
      'Scrubok, replikációk és frissítések a zárolt képernyőn és az értesítések között';

  @override
  String get jobKindScrub => 'Scrub';

  @override
  String get jobKindReplication => 'Replikáció';

  @override
  String get jobKindAppUpdate => 'Alkalmazásfrissítés';

  @override
  String get jobKindCloudSync => 'Felhőszinkron';

  @override
  String get jobKindCloudBackup => 'Felhős mentés';

  @override
  String get jobKindRsync => 'Rsync feladat';

  @override
  String get jobKindSystemUpdate => 'Rendszerfrissítés';

  @override
  String get jobsStale => 'Nem frissül, nyisd meg az alkalmazást';

  @override
  String get jobsConnectionLost =>
      'A kapcsolat megszakadt, az állapot lehet, hogy elavult';

  @override
  String jobsMoreCount(int count) {
    return '+$count további';
  }

  @override
  String get jobsChannelName => 'Feladatok állapota';

  @override
  String get jobsChannelDescription =>
      'Scrubok, replikációk és frissítések előrehaladása';

  @override
  String get serversLoadErrorTitle => 'Nem olvashatók a mentett szerverek';

  @override
  String get serversLoadErrorBody =>
      'Semmi nem törlődött. A telefon biztonságos tárolója nem válaszolt. Próbáld újra; ha tartósan nem megy, töröld a listát, és add hozzá újra a szervereket.';

  @override
  String get serversClearAction => 'Mentett szerverek törlése';

  @override
  String get serversClearTitle => 'Törlöd a mentett szervereket?';

  @override
  String get serversClearBody =>
      'Minden ebben az alkalmazásban mentett szerver törlődik belőle. Magukon a szervereken semmi nem változik.';

  @override
  String get serversClearConfirm => 'Törlés';

  @override
  String serverSaveFailed(String error) {
    return 'A szervert nem sikerült elmenteni: $error';
  }
}
