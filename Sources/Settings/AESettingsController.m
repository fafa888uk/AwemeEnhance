#import "AESettingsController.h"
#import "Core/AEConfig.h"
#import "Core/AERuntime.h"
#import "Core/AELog.h"
#import "Spark/AESpark.h"
#import "Modules/AEModules.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

@interface AESettingsController () <UIDocumentPickerDelegate>
@property(nonatomic, copy) NSString *page;
@property(nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *groups;
@property(nonatomic, copy) NSArray<NSString *> *headings;
@property(nonatomic) BOOL pickingVideo;
@end
static NSDictionary *Toggle(NSString *title,NSString *key) { return @{@"title":title,@"key":key}; }
static NSDictionary *Action(NSString *title,NSString *action) { return @{@"title":title,@"action":action}; }

@implementation AESettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=self.page ?: @"AwemeEnhance";
    self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=54;
    self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:AEConfigChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:@"AESparkDueChanged" object:nil];
    [self reload];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)reload {
    if (!self.isViewLoaded) return;
    if ([self.page isEqual:@"火花管理"]) {
        NSMutableArray *people=[NSMutableArray array];
        for (NSDictionary *f in AESparkStore.shared.friends) [people addObject:@{@"title":[NSString stringWithFormat:@"%@ · %@ · %02ld:%02ld",f[@"alias"],[f[@"enabled"] boolValue]?@"启用":@"关闭",[f[@"minute"] integerValue]/60,[f[@"minute"] integerValue]%60],@"friend":f}];
        self.headings=@[@"仅提醒 + 手动确认，无自动发送",@"自选好友（本地别名，不读取通讯录）"];
        self.groups=@[@[Toggle(@"启用火花提醒（需明确授权）",@"sparkEnabled"),Action(@"添加指定好友",@"addFriend"),Action(@"待发送消息",@"due"),Action(@"准备 / 手动确认记录",@"history")],people];
    } else if ([self.page isEqual:@"待发送消息"]) {
        NSMutableArray *rows=[NSMutableArray array]; for (NSDictionary *f in AESparkScheduler.shared.dueFriends) [rows addObject:@{@"title":f[@"alias"],@"dueFriend":f}];
        self.headings=@[@"选择后预览，确认才写入剪贴板；需到官方聊天手动发送"];
        self.groups=@[rows];
    } else {
        self.headings=@[@"安全控制",@"广告过滤与推荐内容管理",@"视频播放设置",@"视频保存设置",@"界面自定义",@"数据与维护"];
        self.groups=@[@[Toggle(@"功能总开关",@"enabled"),Toggle(@"实验适配器（更改后重启应用）",@"experimentalAdapters")],
          @[Toggle(@"过滤信息流广告",@"filterAds"),Toggle(@"隐藏推荐直播",@"filterLive"),Toggle(@"关键词过滤",@"filterKeywords"),Action(@"编辑屏蔽关键词",@"keywords")],
          @[Toggle(@"优先最高候选画质（保留降级）",@"highestQuality"),Toggle(@"自定义播放倍速",@"customSpeed"),Action(@"播放倍速 0.25–3.0",@"rate"),Toggle(@"显示原生进度条（拖动待验证）",@"progress")],
          @[Toggle(@"允许导出自己拥有的本地原片",@"saveOriginal"),Action(@"选择本地原片并保存",@"video"),Action(@"应用内无水印保存：待授权素材接口",@"saveLimit")],
          @[Toggle(@"隐藏顶部导航栏",@"hideTop"),Toggle(@"隐藏底部导航栏",@"hideBottom"),Toggle(@"隐藏指定界面按钮",@"hideButtons"),Action(@"隐藏按钮的无障碍标签",@"hiddenButtons"),Toggle(@"自定义导航栏透明度",@"customOpacity"),Action(@"透明度 0.2–1.0",@"opacity")],
          @[Action(@"火花管理",@"spark"),Action(@"导出配置（不含好友和消息）",@"export"),Action(@"导入配置",@"import"),Action(@"运行日志",@"logs"),Action(@"版本信息 / 运行时兼容状态",@"about"),Action(@"恢复默认并清除本地火花数据",@"reset")]];
    }
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.groups.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.groups[s].count; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return self.headings[s]; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; NSDictionary *row=self.groups[p.section][p.row];
    cell.textLabel.text=row[@"title"]; cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody]; cell.textLabel.adjustsFontForContentSizeCategory=YES; cell.textLabel.numberOfLines=0;
    if (row[@"key"]) { UISwitch *s=[UISwitch new]; s.accessibilityIdentifier=row[@"key"]; s.on=[AEConfig.shared flag:row[@"key"]]; [s addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=s; }
    else cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)message:(NSString *)title body:(NSString *)body {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)toggle:(UISwitch *)s {
    NSString *key=s.accessibilityIdentifier;
    if (s.on && ([key isEqual:@"sparkEnabled"] || [key isEqual:@"experimentalAdapters"])) {
        s.on=NO;
        NSString *body=[key isEqual:@"sparkEnabled"] ? @"只为你主动选择的好友创建本地提醒。消息不自动发送、不读取账号或聊天。你需到官方聊天核对接收者并手动发送；本地限每好友每日准备一次、全局间隔至少60秒，这不是平台发送额度。允许吗？" : @"41.2.0 与 41.3.0 均未通过真机验收。ABI 匹配也不保证语义兼容。启用后重启应用生效，异常模块将停用。继续吗？";
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"明确授权" message:body preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"我已理解并允许" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
            if ([key isEqual:@"sparkEnabled"]) { [AEConfig.shared setValue:@YES forOption:@"sparkConsent"]; [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionSound completionHandler:^(__unused BOOL granted,__unused NSError *error){ [AESparkScheduler.shared reconcile]; }]; }
            [AEConfig.shared setValue:@YES forOption:key];
        }]]; [self presentViewController:a animated:YES completion:nil]; return;
    }
    [AEConfig.shared setValue:@(s.on) forOption:key];
    if ([key isEqual:@"sparkEnabled"] && !s.on) [AEConfig.shared setValue:@NO forOption:@"sparkConsent"];
}
- (void)push:(NSString *)page { AESettingsController *c=[AESettingsController new]; c.page=page; [self.navigationController pushViewController:c animated:YES]; }
- (void)editOption:(NSString *)key {
    id old=[AEConfig.shared value:key]; BOOL list=[old isKindOfClass:NSArray.class];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:key message:list?@"用英文逗号分隔；最多100项。":@"输入允许范围内的数值。" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.text=list?[old componentsJoinedByString:@","]:[old description]; }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        NSString *text=a.textFields.firstObject.text ?: @""; id value=nil;
        if (list) { NSMutableArray *parts=[NSMutableArray array]; for (NSString *s in [text componentsSeparatedByString:@","]) { NSString *w=[s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (w.length) [parts addObject:w]; } value=parts; }
        else { NSScanner *scan=[NSScanner scannerWithString:text]; double number=0; if ([scan scanDouble:&number] && scan.isAtEnd) value=@(number); }
        if (!value || ![AEConfig.shared setValue:value forOption:key]) [self message:@"配置无效" body:@"请检查类型、长度和允许范围。"]; [self reload];
    }]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)editFriend:(NSDictionary *)old {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"指定好友" message:@"本地别名需唯一；发送前须在官方聊天中重新核对好友。时间固定使用创建时的时区。" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *values=@[old[@"alias"] ?: @"", old[@"message"] ?: @"今天也要开心", old ? [NSString stringWithFormat:@"%02ld:%02ld",[old[@"minute"] integerValue]/60,[old[@"minute"] integerValue]%60] : @"20:00"];
    NSArray *names=@[@"自选好友别名（不自动查找账号）",@"自定义消息 / 表情",@"HH:mm，24小时制"];
    for (NSUInteger i=0;i<3;i++) [a addTextFieldWithConfigurationHandler:^(UITextField *f){ f.placeholder=names[i]; f.text=values[i]; }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    for (NSNumber *enable in @[@NO,@YES]) {
      [a addAction:[UIAlertAction actionWithTitle:enable.boolValue?@"保存并启用此好友":@"保存为关闭" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        NSString *time=a.textFields[2].text ?: @"";
        NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"^([01][0-9]|2[0-3]):[0-5][0-9]$" options:0 error:nil];
        if (![re firstMatchInString:time options:0 range:NSMakeRange(0,time.length)]) { [self message:@"时间无效" body:@"请输入 HH:mm。"]; return; }
        NSArray *parts=[time componentsSeparatedByString:@":"];
        NSDictionary *f=@{@"id":old[@"id"] ?: NSUUID.UUID.UUIDString,@"alias":[a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"",@"message":a.textFields[1].text ?: @"",@"minute":@([parts[0] integerValue]*60+[parts[1] integerValue]),@"timezone":old[@"timezone"] ?: NSTimeZone.localTimeZone.name,@"enabled":enable};
        if (![AESparkStore.shared saveFriend:f]) [self message:@"未保存" body:@"别名重复、超过32位好友、字段无效或本地存储不可用。"];
        [AESparkScheduler.shared reconcile]; [self reload];
      }]];
    }
    [self presentViewController:a animated:YES completion:nil];
}
- (void)prepare:(NSDictionary *)f {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:f[@"alias"] message:f[@"message"] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"确认准备消息（不自动发送）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        NSString *day=[AESparkScheduler.shared dayForFriend:f];
        BOOL stillDue=NO; for (NSDictionary *current in AESparkScheduler.shared.dueFriends) if ([current isEqual:f]) stillDue=YES;
        if (!stillDue || ![AESparkStore.shared prepare:f[@"id"] day:day now:NSDate.date]) { [self message:@"操作已阻止" body:@"配置已变更、今天已准备过、60秒冷却中或存储失败。不会自动重试。"]; return; }
        [UIPasteboard.generalPasteboard setItems:@[@{@"public.utf8-plain-text":f[@"message"]}] options:@{UIPasteboardOptionLocalOnly:@YES,UIPasteboardOptionExpirationDate:[NSDate dateWithTimeIntervalSinceNow:120]}];
        [self message:@"待手动发送" body:@"消息临时写入本机剪贴板（120秒）。请关闭设置，在官方聊天界面核对好友后手动粘贴并发送。本项目不能验证官方投递结果。记录页可由你手动确认已发送。"];
        [self reload];
    }]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)history {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"准备 / 手动确认记录" message:@"prepared 不是已发送；manual-confirmed 仅为用户自报，不是平台回执。选择最近记录可手动确认。" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *records=AESparkStore.shared.history;
    for (NSDictionary *r in [[records reverseObjectEnumerator] allObjects]) {
        if (a.actions.count>=15) break;
        NSString *alias=@"已删除好友"; for (NSDictionary *f in AESparkStore.shared.friends) if ([f[@"id"] isEqual:r[@"id"]]) alias=f[@"alias"];
        NSString *title=[NSString stringWithFormat:@"%@ %@ %@",r[@"day"],alias,r[@"status"]];
        [a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
            UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"手动确认已发送？" message:@"仅在你已于官方界面完成发送时确认；本项目不会因此发送任何消息。" preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"我已手动发送" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){ if (![AESparkStore.shared confirmManual:r[@"id"] day:r[@"day"]]) [self message:@"记录失败" body:@"未能写入本地记录。"]; }]];
            [self presentViewController:confirm animated:YES completion:nil];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView=self.view; a.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);
    [self presentViewController:a animated:YES completion:nil];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES]; NSDictionary *row=self.groups[p.section][p.row]; NSString *action=row[@"action"];
    if (row[@"friend"]) { [self editFriend:row[@"friend"]]; return; }
    if (row[@"dueFriend"]) { [self prepare:row[@"dueFriend"]]; return; }
    if ([@[@"rate",@"opacity",@"keywords",@"hiddenButtons"] containsObject:action]) [self editOption:action];
    else if ([action isEqual:@"spark"]) [self push:@"火花管理"];
    else if ([action isEqual:@"due"]) [self push:@"待发送消息"];
    else if ([action isEqual:@"addFriend"]) [self editFriend:nil];
    else if ([action isEqual:@"history"]) [self history];
    else if ([action isEqual:@"saveLimit"]) [self message:@"待验证 / 未接入" body:@"尚无经过验证且能确认保存权限与原片来源的抖音素材接口。不会改写下载权限或从第三方解析站获取视频。当前仅支持导出你在文件选择器主动选择、并确认拥有的本地原片。"];
    else if ([action isEqual:@"about"]) [self message:@"0.1.0 · MIT" body:[NSString stringWithFormat:@"宿主 %@\n41.2.0 / 41.3.0 均未通过真机验收\n%@\n后台自动私信：未实现；无私信发送 API。",AERuntime.shared.hostVersion,AERuntime.shared.status]];
    else if ([action isEqual:@"logs"]) [self message:@"内存运行日志（最多200项）" body:AELog.entries.description];
    else if ([action isEqual:@"reset"]) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"恢复默认？" message:@"关闭全部功能、撤回火花授权并删除本地好友、草稿与记录。" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"恢复默认" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x){ [AEConfig.shared reset]; BOOL ok=[AESparkStore.shared reset]; [AELog clear]; [AESparkScheduler.shared reconcile]; [self reload]; if (!ok) [self message:@"清除失败" body:@"存储不可用；功能已关闭，请通过系统删除应用数据。"]; }]]; [self presentViewController:a animated:YES completion:nil];
    } else if ([action isEqual:@"export"]) {
        NSData *data=[NSJSONSerialization dataWithJSONObject:AEConfig.shared.exportConfiguration options:NSJSONWritingPrettyPrinted error:nil];
        NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"AwemeEnhance-options.json"]];
        if (![data writeToURL:url options:NSDataWritingAtomic error:nil]) return;
        UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil]; share.popoverPresentationController.sourceView=self.view; [self presentViewController:share animated:YES completion:nil];
    } else if ([action isEqual:@"import"] || [action isEqual:@"video"]) {
        self.pickingVideo=[action isEqual:@"video"];
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[self.pickingVideo ? UTTypeMovie : UTTypeJSON] asCopy:YES]; picker.delegate=self; [self presentViewController:picker animated:YES completion:nil];
    }
}
- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)p { return self.groups[p.section][p.row][@"friend"]!=nil; }
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)p {
    if (style==UITableViewCellEditingStyleDelete) { NSDictionary *f=self.groups[p.section][p.row][@"friend"]; [AESparkStore.shared removeFriend:f[@"id"]]; [AESparkScheduler.shared reconcile]; [self reload]; }
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url=urls.firstObject; if (!url) return;
    if (!self.pickingVideo) {
        NSNumber *size; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        if (size.unsignedLongLongValue>65536) { [self message:@"导入失败" body:@"配置文件超过64 KiB。"]; return; }
        NSData *data=[NSData dataWithContentsOfURL:url]; id object=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        BOOL imported=[object isKindOfClass:NSDictionary.class] && [AEConfig.shared importConfiguration:object];
        [self message:imported?@"导入成功":@"导入失败" body:@"导入不会包含或开启火花授权；实验适配器变更需重启。"]; return;
    }
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"原片保存权限" message:@"仅当此文件是你有权保存的原片时继续。此操作不会移除已有水印，也不会绕过作者保存限制。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"确认我拥有保存权" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){ [AESave exportLocalOriginal:url userOwnsOriginal:YES completion:^(BOOL ok){ [self message:ok?@"已保存到相册":@"未保存" body:ok?@"原文件未修改。":@"请检查总开关、保存开关、相册权限、宿主隐私描述与文件格式。"]; }]; }]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@interface AEEntry : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)open:(UILongPressGestureRecognizer *)gesture;
@end
@implementation AEEntry
+ (instancetype)shared { static AEEntry *s; static dispatch_once_t once; dispatch_once(&once, ^{ s=[self new]; }); return s; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
- (void)open:(UILongPressGestureRecognizer *)g {
    if (g.state!=UIGestureRecognizerStateBegan) return;
    UIViewController *top=g.view.window.rootViewController; if (!top && [g.view isKindOfClass:UIWindow.class]) top=((UIWindow *)g.view).rootViewController;
    while (top.presentedViewController) top=top.presentedViewController;
    if (!top || ([top isKindOfClass:UINavigationController.class] && [((UINavigationController *)top).topViewController isKindOfClass:AESettingsController.class])) return;
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[AESettingsController new]]; [top presentViewController:nav animated:YES completion:nil];
}
@end
void AEInstallSettingsGesture(UIWindow *window) {
    static char installed;
    if (!NSThread.isMainThread || !window || window.windowLevel!=UIWindowLevelNormal || objc_getAssociatedObject(window,&installed)) return;
    UILongPressGestureRecognizer *g=[[UILongPressGestureRecognizer alloc] initWithTarget:AEEntry.shared action:@selector(open:)];
    g.numberOfTouchesRequired=2; g.minimumPressDuration=1; g.cancelsTouchesInView=NO; g.delegate=AEEntry.shared;
    [window addGestureRecognizer:g]; objc_setAssociatedObject(window,&installed,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
