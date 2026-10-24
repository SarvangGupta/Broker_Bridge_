import 'dart:io';

/// Project reference of the production Supabase backend used by RMBuyer.
/// Test-time traffic to this project is always refused.
const String productionSupabaseProjectRef = 'imztlkvkxzeaekxvmcfe';

/// Thrown when a test attempts a network request it is not allowed to make.
class TestNetworkAccessBlocked implements Exception {
  final Uri url;
  final String reason;

  const TestNetworkAccessBlocked(this.url, this.reason);

  @override
  String toString() =>
      'TestNetworkAccessBlocked: request to ${url.scheme}://${url.host} refused ($reason)';
}

bool isProductionSupabaseHost(String host) =>
    host.toLowerCase().contains(productionSupabaseProjectRef);

bool isLoopbackHost(String host) {
  final h = host.toLowerCase();
  return h == 'localhost' || h == '127.0.0.1' || h == '::1' || h == '[::1]';
}

/// Fail-closed network policy for `flutter test`:
/// - the production Supabase project is always refused;
/// - loopback hosts are allowed (local fakes such as `localhost:54321`);
/// - any other host is refused unless explicitly listed in [allowedHosts]
///   (only an approved, non-production live-test backend is ever listed).
class TestNetworkGuardOverrides extends HttpOverrides {
  final Set<String> allowedHosts;

  TestNetworkGuardOverrides({Set<String> allowedHosts = const {}})
      : allowedHosts = allowedHosts.map((h) => h.toLowerCase()).toSet();

  void checkUrl(Uri url) {
    final host = url.host.toLowerCase();
    if (isProductionSupabaseHost(host)) {
      throw TestNetworkAccessBlocked(url, 'production Supabase project');
    }
    if (isLoopbackHost(host) || allowedHosts.contains(host)) return;
    throw TestNetworkAccessBlocked(url, 'host not allowed during tests');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _GuardedHttpClient(super.createHttpClient(context), checkUrl);
}

/// Delegating [HttpClient] that validates every request target before connecting.
class _GuardedHttpClient implements HttpClient {
  final HttpClient _inner;
  final void Function(Uri url) _check;

  _GuardedHttpClient(this._inner, this._check);

  Future<HttpClientRequest> _guard(Uri url, Future<HttpClientRequest> Function() open) {
    try {
      _check(url);
    } catch (e) {
      return Future<HttpClientRequest>.error(e);
    }
    return open();
  }

  Uri _uri(String host, int port, String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.open(method, host, port, path));
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _guard(url, () => _inner.openUrl(method, url));
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.get(host, port, path));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _guard(url, () => _inner.getUrl(url));
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.post(host, port, path));
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _guard(url, () => _inner.postUrl(url));
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.put(host, port, path));
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _guard(url, () => _inner.putUrl(url));
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.delete(host, port, path));
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _guard(url, () => _inner.deleteUrl(url));
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.patch(host, port, path));
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _guard(url, () => _inner.patchUrl(url));
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _guard(_uri(host, port, path), () => _inner.head(host, port, path));
  @override
  Future<HttpClientRequest> headUrl(Uri url) => _guard(url, () => _inner.headUrl(url));

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;
  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;
  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;
  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);
  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f,
  ) =>
      _inner.connectionFactory = f;
  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;
  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)? f,
  ) =>
      _inner.authenticateProxy = f;
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _inner.badCertificateCallback = callback;
  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;
  @override
  void close({bool force = false}) => _inner.close(force: force);
}
