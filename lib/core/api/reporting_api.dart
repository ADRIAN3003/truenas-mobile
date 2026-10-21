import '../models/json.dart';
import '../models/reporting.dart';
import 'json_rpc_client.dart';
import 'method_catalog.dart';

/// History of CPU, network, disk temperature and ARC from the server's
/// reporting (netdata). 25.04 names the methods `reporting.netdata_graphs`
/// and `reporting.netdata_get_data`; newer releases also answer to
/// `reporting.graphs` and `reporting.get_data`.
class ReportingApi {
  ReportingApi(this._client, this._catalog);

  final JsonRpcClient _client;
  final MethodCatalog _catalog;

  Future<String?> _method(String netdata, String plain) async {
    if (await _catalog.has(netdata)) return netdata;
    if (await _catalog.has(plain)) return plain;
    return null;
  }

  Future<String?> _graphsMethod() =>
      _method('reporting.netdata_graphs', 'reporting.graphs');

  Future<String?> _dataMethod() =>
      _method('reporting.netdata_get_data', 'reporting.get_data');

  /// Whether the server can give history at all.
  Future<bool> isAvailable() async =>
      await _graphsMethod() != null && await _dataMethod() != null;

  /// The graphs the server offers, with what each can be asked about.
  Future<List<ReportingGraph>> graphs() async {
    final method = await _graphsMethod();
    if (method == null) return const [];
    return parseGraphs(await _client.call(method));
  }

  /// The samples of [requests] over [range], in the same order. A graph the
  /// server could not answer is left out.
  Future<List<ReportingData>> data(
    List<ReportingRequest> requests,
    ReportingRange range,
  ) async {
    final method = await _dataMethod();
    if (method == null || requests.isEmpty) return const [];
    final result = await _client.call(method, [
      [
        for (final r in requests)
          {
            'name': r.name,
            if (r.identifier != null) 'identifier': r.identifier,
          },
      ],
      {'unit': range.unit},
    ]);
    return [
      for (final item in result as List? ?? const [])
        ReportingData.fromJson(asMap(item)),
    ];
  }
}
