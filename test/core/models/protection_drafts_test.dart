import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/protection.dart';
import 'package:truenas_mobile/core/models/protection_drafts.dart';

void main() {
  group('ReplicationDraft', () {
    test('round-trips a pull task with a custom schedule', () {
      final draft = ReplicationDraft.fromJson({
        'name': 'from-remote',
        'direction': 'PULL',
        'transport': 'SSH',
        'ssh_credentials': {'id': 3, 'name': 'box'},
        'source_datasets': ['data'],
        'target_dataset': 'tank/data',
        'recursive': true,
        'periodic_snapshot_tasks': [],
        'naming_schema': ['daily-%Y%m%d'],
        'also_include_naming_schema': [],
        'auto': true,
        'schedule': {'minute': '15', 'hour': '3', 'dom': '*', 'month': '*'},
        'retention_policy': 'CUSTOM',
        'lifetime_value': 6,
        'lifetime_unit': 'MONTH',
      });
      expect(draft.push, isFalse);
      expect(draft.sshCredentials, 3);
      expect(draft.namingSchema, 'daily-%Y%m%d');
      expect(draft.schedule, '15 3 * * *');

      final json = draft.toJson();
      expect(json['direction'], 'PULL');
      expect(json['naming_schema'], ['daily-%Y%m%d']);
      expect(json['also_include_naming_schema'], isEmpty);
      expect(json['periodic_snapshot_tasks'], isEmpty);
      // An unchanged custom schedule is left alone.
      expect(json.containsKey('schedule'), isFalse);
      expect(json['lifetime_value'], 6);
      expect(json['netcat_active_side'], isNull);
      expect(json.containsKey('compression'), isFalse);
      expect(json['lifetime_unit'], 'MONTH');
    });

    test('keeps a regex match and clears the schedule when manual', () {
      final draft = ReplicationDraft.fromJson({
        'name': 'regex',
        'direction': 'PUSH',
        'transport': 'LOCAL',
        'periodic_snapshot_tasks': [
          {'id': 4},
        ],
        'name_regex': 'auto-.*',
        'auto': false,
        'retention_policy': 'NONE',
      });
      expect(draft.snapshotTasks, [4]);
      final json = draft.toJson();
      expect(json.containsKey('naming_schema'), isFalse);
      expect(json.containsKey('also_include_naming_schema'), isFalse);
      expect(json['schedule'], isNull);
      expect(json['lifetime_value'], isNull);
      expect(json['ssh_credentials'], isNull);
      expect(json.containsKey('compression'), isTrue);
      expect(json['compression'], isNull);
    });

    test('a new push without snapshot tasks sends by name pattern', () {
      final json =
          (ReplicationDraft()
                ..name = 'n'
                ..sourceDatasets = ['tank'])
              .toJson();
      expect(json['also_include_naming_schema'], [defaultNamingSchema]);
      expect(json['schedule'], {
        ...SnapshotSchedule.daily.cron,
        'begin': '00:00',
        'end': '23:59',
      });
    });
  });

  group('CloudSyncDraft', () {
    test('keeps provider attributes and drops an emptied bucket', () {
      final draft = CloudSyncDraft.fromJson({
        'description': 'Photos',
        'credentials': {'id': 2},
        'attributes': {'bucket': 'old', 'folder': 'pics', 'fast_list': true},
        'path': '/mnt/tank/photos',
        'direction': 'PULL',
        'transfer_mode': 'SYNC',
        'schedule': {'minute': '0', 'hour': '*', 'dom': '*', 'month': '*'},
      });
      expect(draft.schedule, SnapshotSchedule.hourly);
      draft.bucket = '';
      final json = draft.toJson();
      expect(json['credentials'], 2);
      expect(json['direction'], 'PULL');
      expect(json['transfer_mode'], 'SYNC');
      expect(json['attributes'], {'folder': 'pics', 'fast_list': true});
      expect(json['schedule'], SnapshotSchedule.hourly.cron);
    });
  });

  group('RsyncDraft', () {
    test('module mode sends host and module, not SSH settings', () {
      final json =
          (RsyncDraft()
                ..ssh = false
                ..remoteHost = 'nas2'
                ..remoteModule = 'data'
                ..sshCredentials = 3)
              .toJson();
      expect(json['mode'], 'MODULE');
      expect(json['remotehost'], 'nas2');
      expect(json['remotemodule'], 'data');
      expect(json['ssh_credentials'], isNull);
      expect(json['remoteport'], isNull);
    });

    test('SSH without a saved connection sends host and port', () {
      final json =
          (RsyncDraft()
                ..remoteHost = 'nas2'
                ..remotePort = 2222)
              .toJson();
      expect(json['mode'], 'SSH');
      expect(json['remotehost'], 'nas2');
      expect(json['remoteport'], 2222);
      expect(json['remotemodule'], isNull);
    });
  });

  group('CloudBackupDraft', () {
    test('an empty password keeps the current one', () {
      final draft = CloudBackupDraft.fromJson({
        'credentials': {'id': 2},
        'attributes': {'bucket': 'b', 'folder': 'f'},
        'path': '/mnt/tank',
        'keep_last': 30,
      });
      expect(draft.toJson().containsKey('password'), isFalse);
      expect(draft.toJson()['keep_last'], 30);
      draft.password = 'new';
      expect(draft.toJson()['password'], 'new');
    });
  });
}
