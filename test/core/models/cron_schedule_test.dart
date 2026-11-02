import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/cron_schedule.dart';
import 'package:truenas_mobile/core/models/protection.dart';

CronDraft draftOf(String cron) {
  final f = cron.split(' ');
  return CronDraft.from(
    CronSchedule(minute: f[0], hour: f[1], dom: f[2], month: f[3], dow: f[4]),
  );
}

void main() {
  group('CronField.accepts', () {
    test('takes stars, numbers, ranges, lists and steps', () {
      for (final ok in ['*', '5', '*/15', '1-5', '1,15,30', '0-30/10']) {
        expect(CronField.minute.accepts(ok), isTrue, reason: ok);
      }
      expect(CronField.hour.accepts('*/6'), isTrue);
      expect(CronField.dom.accepts('31'), isTrue);
      expect(CronField.month.accepts('jan,6'), isTrue);
      expect(CronField.dow.accepts('mon-fri'), isTrue);
      expect(CronField.dow.accepts('7'), isTrue);
    });

    test('refuses what is out of range or malformed', () {
      expect(CronField.minute.accepts(''), isFalse);
      expect(CronField.minute.accepts('60'), isFalse);
      expect(CronField.hour.accepts('24'), isFalse);
      expect(CronField.dom.accepts('0'), isFalse);
      expect(CronField.month.accepts('13'), isFalse);
      expect(CronField.dow.accepts('8'), isFalse);
      expect(CronField.minute.accepts('*/0'), isFalse);
      expect(CronField.minute.accepts('5-1'), isFalse);
      expect(CronField.minute.accepts('1-2-3'), isFalse);
      expect(CronField.minute.accepts('a'), isFalse);
      expect(CronField.minute.accepts('1,,2'), isFalse);
      expect(CronField.hour.accepts('mon'), isFalse);
      expect(CronField.dow.accepts('jan'), isFalse);
    });
  });

  group('CronDraft.from', () {
    test('reads the shapes the editor builds', () {
      expect(draftOf('*/15 * * * *').mode, CronMode.minutes);
      expect(draftOf('*/15 * * * *').interval, 15);
      expect(draftOf('* * * * *').interval, 1);

      var d = draftOf('30 */6 * * *');
      expect((d.mode, d.interval, d.minute), (CronMode.hourly, 6, 30));
      expect(draftOf('0 * * * *').mode, CronMode.hourly);

      d = draftOf('05 03 * * *');
      expect((d.mode, d.hour, d.minute), (CronMode.daily, 3, 5));

      d = draftOf('0 2 * * 1,3,5');
      expect(d.mode, CronMode.weekly);
      expect(d.weekdays, {1, 3, 5});
      expect(draftOf('0 2 * * 7').weekdays, {0});

      d = draftOf('0 4 15 * *');
      expect((d.mode, d.day, d.hour), (CronMode.monthly, 15, 4));
    });

    test('keeps anything else as typed', () {
      for (final cron in [
        '*/7 * * * *',
        '0 */5 * * *',
        '0 8-18 * * *',
        '0 2 * 6 *',
        '0 2 1 * 1',
        '0 2 * * 1-5',
        '0,30 * * * *',
        '0 2 0 * *',
      ]) {
        final d = draftOf(cron);
        expect(d.mode, CronMode.advanced, reason: cron);
        expect(d.build().text, cron, reason: cron);
      }
    });

    test('starts from a daily midnight schedule', () {
      expect(CronDraft.from(null).build().text, '0 0 * * *');
    });
  });

  group('CronDraft.build', () {
    test('round trips every simple mode', () {
      for (final cron in [
        '*/5 * * * *',
        '* * * * *',
        '15 */4 * * *',
        '15 * * * *',
        '45 23 * * *',
        '0 6 * * 0,6',
        '30 1 28 * *',
      ]) {
        expect(draftOf(cron).build().text, cron);
      }
    });

    test('switching to advanced keeps what the mode said', () {
      final d = draftOf('0 6 * * 1')..switchTo(CronMode.advanced);
      expect(d.advanced, ['0', '6', '*', '*', '1']);
    });

    test('switching modes picks a valid interval', () {
      final d = draftOf('0 6 * * *')
        ..interval = 7
        ..switchTo(CronMode.minutes);
      expect(d.interval, 5);
      d.interval = 5;
      d.switchTo(CronMode.hourly);
      expect(d.interval, 1);
    });

    test('weekly needs a day, advanced needs valid fields', () {
      final d = draftOf('0 6 * * 1')..weekdays.clear();
      expect(d.isValid, isFalse);
      final a = draftOf('0 6 1 * 1')..advanced[0] = '99';
      expect(a.isValid, isFalse);
    });

    test('carries the time window of the schedule being edited', () {
      final d = CronDraft.from(
        const CronSchedule(
          minute: '0',
          hour: '2',
          begin: '01:00',
          end: '05:00',
        ),
      );
      expect(d.build().toJson(), containsPair('begin', '01:00'));
      expect(d.build().toJson(), containsPair('end', '05:00'));
    });
  });

  group('schedules for the server', () {
    test('presets and custom schedules become cron objects', () {
      expect(scheduleRequest(SnapshotSchedule.weekly), {
        'minute': '0',
        'hour': '0',
        'dom': '*',
        'month': '*',
        'dow': '0',
      });
      expect(scheduleRequest(const CronSchedule(minute: '5'), window: true), {
        'minute': '5',
        'hour': '*',
        'dom': '*',
        'month': '*',
        'dow': '*',
        'begin': '00:00',
        'end': '23:59',
      });
      expect(scheduleRequest(null), isNull);
    });

    test('a preset is read back as itself, anything else as cron', () {
      expect(
        parseSchedule({
          'minute': '00',
          'hour': '*',
          'dom': '*',
          'month': '*',
          'dow': '*',
        }),
        SnapshotSchedule.hourly,
      );
      expect(
        parseSchedule({'minute': '0', 'hour': '3'}),
        const CronSchedule(minute: '0', hour: '3'),
      );
    });
  });
}
