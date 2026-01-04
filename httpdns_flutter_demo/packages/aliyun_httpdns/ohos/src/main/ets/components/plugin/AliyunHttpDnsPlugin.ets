import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import Logger from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { httpdns, HttpDnsConfig, IHttpDnsService, IpType } from '@aliyun/httpdns';
import common from '@ohos.app.ability.common';

const TAG = "AliyunHttpDnsPlugin";

export default class AliyunHttpDnsPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private applicationContext: Context | null = null;
  private httpDnsService: IHttpDnsService | null = null;

  getUniqueClassName(): string {
    return "AliyunHttpDnsPlugin";
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "aliyun_httpdns");
    this.channel.setMethodCallHandler(this);
    this.applicationContext = binding.getApplicationContext();
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.applicationContext = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const args = call.args as Record<string, Object>;
    switch (call.method) {
      case "initialize":
        this.initialize(args, result);
        break;
      case "build":
        this.build(result);
        break;
      case "setLogEnabled":
        this.setLogEnabled(args, result);
        break;
      case "setPersistentCacheIPEnabled":
        this.setPersistentCacheIPEnabled(args, result);
        break;
      case "setReuseExpiredIPEnabled":
        this.setReuseExpiredIPEnabled(args, result);
        break;
      case "setHttpsRequestEnabled":
        this.setHttpsRequestEnabled(args, result);
        break;
      case "resolveHostSyncNonBlocking":
        this.resolveHostSyncNonBlocking(args, result);
        break;
      case "resolve":
        this.resolve(args, result);
        break;
      case "setPreResolveHosts":
        this.setPreResolveHosts(args, result);
        break;
      case "setPreResolveAfterNetworkChanged":
        this.setPreResolveAfterNetworkChanged(args, result);
        break;
      case "getSessionId":
        this.getSessionId(result);
        break;
      case "cleanAllHostCache":
        this.cleanAllHostCache(result);
        break;
      case "setIPRankingList":
        this.setIPRankingList(args, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private async initialize(args: ESObject, result: MethodResult): Promise<void> {
    let idVal: ESObject = null;
    let secretKeyVal: ESObject = null;
    let useHttpsVal: ESObject = null;
    let accountId: string | undefined = undefined;
    let secretKey: string | undefined = undefined;
    // useHttps 仅对鸿蒙生效，Android/iOS 请使用 setHttpsRequestEnabled 方法
    let useHttps: boolean = false;

    if (args instanceof Map) {
        if (args.has('accountId')) idVal = args.get('accountId');
        if (args.has('secretKey')) secretKeyVal = args.get('secretKey');
        if (args.has('useHttps')) useHttpsVal = args.get('useHttps');
    } else {
        if (args['accountId']) idVal = args['accountId'];
        if (args['secretKey']) secretKeyVal = args['secretKey'];
        if (args['useHttps'] !== undefined) useHttpsVal = args['useHttps'];
    }

    if (typeof idVal === 'number') {
        accountId = idVal.toString();
    } else if (typeof idVal === 'string') {
        accountId = idVal;
    }
    
    if (typeof secretKeyVal === 'string') {
        secretKey = secretKeyVal;
    }
    
    if (typeof useHttpsVal === 'boolean') {
        useHttps = useHttpsVal;
    }

    if (!accountId) {
        Logger.e(TAG, "initialize failed: accountId is missing");
        result.error("INVALID_ARGS", "accountId is required", null);
        return;
    }

    // configService must be called before getService
    const config: HttpDnsConfig = {};
    if (secretKey) {
        config.secretKey = secretKey;
    }
    // useHttps 仅对鸿蒙生效
    config.useHttps = useHttps;
    if (this.applicationContext) {
        config.context = this.applicationContext as common.UIAbilityContext;
    }
    
    try {
        httpdns.configService(accountId, config);
        httpdns.getService(accountId)
            .then((service) => {
                this.httpDnsService = service;
                result.success(true);
            })
            .catch((err: Error) => {
                Logger.e(TAG, `getService failed: ${err}`);
                result.error("INIT_ERROR", `Exception during init: ${err}`, null);
            });
            
    } catch (e) {
        Logger.e(TAG, `initialize failed: ${e}`);
        result.error("INIT_ERROR", `Exception during init: ${e}`, null);
    }
  }

  private build(result: MethodResult): void {
    if (this.httpDnsService) {
        result.success(true);
    } else {
        result.error("UNINITIALIZED", "HttpDnsService not initialized", null);
    }
  }

  private setLogEnabled(args: Record<string, Object>, result: MethodResult): void {
    const enabled = args['enabled'] as boolean;
    if (enabled) {
        httpdns.enableHiLog();
    }
    result.success(null);
  }

  private setPersistentCacheIPEnabled(args: Record<string, Object>, result: MethodResult): void {
    // 鸿蒙 SDK 暂不支持此接口，通过 configService 配置
    result.success(null);
  }

  private setReuseExpiredIPEnabled(args: Record<string, Object>, result: MethodResult): void {
    // 鸿蒙 SDK 暂不支持此接口
    result.success(null);
  }

  private setHttpsRequestEnabled(args: Record<string, Object>, result: MethodResult): void {
    // useHttps 需要在初始化时通过 configService 配置
    if (!this.httpDnsService) {
      result.error("UNINITIALIZED", "Service not initialized", null);
      return;
    }
    result.success(null);
  }

  private async resolveHostSyncNonBlocking(args: ESObject, result: MethodResult): Promise<void> {
    let hostname: string | undefined;
    let ipTypeStr: string | undefined;
    
    if (args instanceof Map) {
        if (args.has('hostname')) hostname = args.get('hostname') as string;
        if (args.has('ipType')) ipTypeStr = args.get('ipType') as string;
    } else {
        if (args['hostname']) hostname = args['hostname'] as string;
        if (args['ipType']) ipTypeStr = args['ipType'] as string;
    }
    
    if (!hostname) {
        result.success({ "ipv4": [], "ipv6": [] });
        return;
    }
    
    let ipType = IpType.Auto;
    if (ipTypeStr === 'v4' || ipTypeStr === 'ipv4') ipType = IpType.V4;
    else if (ipTypeStr === 'v6' || ipTypeStr === 'ipv6') ipType = IpType.V6;
    else if (ipTypeStr === 'both') ipType = IpType.Both;
    
    if (!this.httpDnsService) {
        result.error("UNINITIALIZED", "Service not initialized", null);
        return;
    }
    
    try {
        // 使用异步方法获取解析结果
        const dnsResult = await this.httpDnsService.getHttpDnsResultAsync(hostname, ipType);
        
        const response : Record<string, string[]> = {
          "ipv4": dnsResult?.ipv4s || [],
          "ipv6": dnsResult?.ipv6s || []
        };
        result.success(response);
    } catch (e) {
        Logger.e(TAG, `getHttpDnsResultAsync error: ${e}`);
        result.success({ "ipv4": [], "ipv6": [] });
    }
  }

  private resolve(args: Record<string, Object>, result: MethodResult): void {
    result.success(null);
  }

  private async setPreResolveHosts(args: Record<string, Object>, result: MethodResult): Promise<void> {
    const hosts = args['hosts'] as string[];
    if (this.httpDnsService) {
        await this.httpDnsService.resolveHosts(hosts); 
    }
    result.success(null);
  }

  private setPreResolveAfterNetworkChanged(args: Record<string, Object>, result: MethodResult): void {
    result.success(null);
  }

  private getSessionId(result: MethodResult): void {
    if (this.httpDnsService) {
        result.success(this.httpDnsService.getSessionId());
    } else {
        result.success(null);
    }
  }

  private async cleanAllHostCache(result: MethodResult): Promise<void> {
    if (this.httpDnsService) {
        await this.httpDnsService.cleanHostCache();
    }
    result.success(null);
  }

  private setIPRankingList(args: Record<string, Object>, result: MethodResult): void {
    result.success(null);
  }
}
