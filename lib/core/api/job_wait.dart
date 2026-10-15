import '../models/job.dart';
import 'api_exception.dart';
import 'json_rpc_client.dart';

/// Waits until job [id] finishes and returns its result. Throws an
/// [ApiException] with the job's error when it fails or is aborted.
Future<Object?> waitForJob(
  JsonRpcClient client,
  int id, {
  Duration poll = const Duration(milliseconds: 500),
  Duration timeout = const Duration(minutes: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final result = await client.call('core.get_jobs', [
      [
        ['id', '=', id],
      ],
    ]) as List<dynamic>;
    if (result.isNotEmpty) {
      final raw = result.first as Map<String, dynamic>;
      final job = TrueNasJob.fromJson(raw);
      switch (job.state) {
        case JobState.success:
          return raw['result'];
        case JobState.failed || JobState.aborted:
          throw ApiException(job.error ?? job.state.name);
        case JobState.waiting || JobState.running:
          break;
      }
    }
    if (DateTime.now().isAfter(deadline)) {
      throw ApiException('Job $id did not finish in time');
    }
    await Future<void>.delayed(poll);
  }
}
