import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';

int getMonthRowCount(DateTime focusedDay) {
  final first = DateTime(focusedDay.year, focusedDay.month, 1);
  final daysBefore = first.weekday % 7; // Sunday = 7 -> 0, Monday = 1 -> 1
  final firstToDisplay = first.subtract(Duration(days: daysBefore));

  final last = DateTime(focusedDay.year, focusedDay.month + 1, 0);
  final daysAfter = (7 - ((last.weekday % 7) + 1)) % 7;
  final lastToDisplay = last.add(Duration(days: daysAfter));

  return (lastToDisplay.difference(firstToDisplay).inDays + 1) ~/ 7;
}

double getMonthHeight(DateTime focusedDay) {
  final rowCount = getMonthRowCount(focusedDay);
  return 80.0 + rowCount * 52.0;
}

DateTime firstDayOfWeek(DateTime day) {
  final daysBefore = day.weekday % 7;
  return DateTime.utc(day.year, day.month, day.day).subtract(Duration(days: daysBefore));
}

bool isDayOnCurrentPage({
  required CalendarFormat format,
  required DateTime focusedDay,
  required DateTime day,
}) {
  final firstDay = DateTime.utc(2022, 1, 1);
  final cleanDay = DateTime.utc(day.year, day.month, day.day);
  switch (format) {
    case CalendarFormat.month:
      return day.year == focusedDay.year && day.month == focusedDay.month;
    case CalendarFormat.twoWeeks:
      final firstWeekDay = firstDayOfWeek(firstDay);
      final pageDay = cleanDay.difference(firstWeekDay).inDays ~/ 14;
      final pageFocused = focusedDay.difference(firstWeekDay).inDays ~/ 14;
      return pageDay == pageFocused;
    case CalendarFormat.week:
      final firstWeekDay = firstDayOfWeek(firstDay);
      final pageDay = cleanDay.difference(firstWeekDay).inDays ~/ 7;
      final pageFocused = focusedDay.difference(firstWeekDay).inDays ~/ 7;
      return pageDay == pageFocused;
  }
}

void main() {
  group('Calendar Month Row Count & Height Calculation Tests', () {
    test('October 2026 requires exactly 5 rows (340.0px)', () {
      final oct2026 = DateTime(2026, 10, 21);
      final rowCount = getMonthRowCount(oct2026);
      expect(rowCount, 5);
      expect(getMonthHeight(oct2026), 340.0);
    });

    test('November 2026 requires exactly 5 rows (340.0px) with NO over-expansion', () {
      final nov2026 = DateTime(2026, 11, 1);
      final rowCount = getMonthRowCount(nov2026);
      expect(rowCount, 5);
      expect(getMonthHeight(nov2026), 340.0);
      expect(getMonthHeight(nov2026), equals(getMonthHeight(DateTime(2026, 10, 21))));
    });

    test('May 2026 (starts Friday, 31 days) requires 6 rows (392.0px)', () {
      final may2026 = DateTime(2026, 5, 15);
      final rowCount = getMonthRowCount(may2026);
      expect(rowCount, 6);
      expect(getMonthHeight(may2026), 392.0);
    });

    test('February 2026 (starts Sunday, 28 days) requires 4 rows or 5 with padding', () {
      final feb2026 = DateTime(2026, 2, 1);
      final rowCount = getMonthRowCount(feb2026);
      expect(rowCount, 4);
      expect(getMonthHeight(feb2026), 80.0 + 4 * 52.0);
    });
  });

  group('Calendar Page Detection Tests', () {
    test('Week format correctly identifies days within the same week', () {
      final focusedDay = DateTime.utc(2026, 10, 21); // Wednesday
      // Oct 18 is Sunday, Oct 24 is Saturday
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.week,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 10, 18),
        ),
        isTrue,
      );
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.week,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 10, 24),
        ),
        isTrue,
      );
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.week,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 10, 17), // Previous week
        ),
        isFalse,
      );
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.week,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 10, 25), // Next week
        ),
        isFalse,
      );
    });

    test('TwoWeeks format correctly identifies days within the 14-day window', () {
      final focusedDay = DateTime.utc(2026, 10, 21);
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.twoWeeks,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 10, 21),
        ),
        isTrue,
      );
    });

    test('Month format detects month boundary correctly', () {
      final focusedDay = DateTime.utc(2026, 10, 21);
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.month,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 10, 1),
        ),
        isTrue,
      );
      expect(
        isDayOnCurrentPage(
          format: CalendarFormat.month,
          focusedDay: focusedDay,
          day: DateTime.utc(2026, 11, 1),
        ),
        isFalse,
      );
    });
  });

  group('TableCalendar Widget Interaction Tests', () {
    testWidgets('Header chevrons are accessible and tap correctly', (tester) async {
      DateTime focusedDay = DateTime.utc(2026, 10, 21);
      DateTime? selectedDay = focusedDay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableCalendar<dynamic>(
              firstDay: DateTime.utc(2022, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              calendarFormat: CalendarFormat.week,
              availableCalendarFormats: const {
                CalendarFormat.week: 'Week',
                CalendarFormat.month: 'Month',
              },
              availableGestures: AvailableGestures.horizontalSwipe,
              pageAnimationEnabled: false,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onPageChanged: (newFocused) {
                focusedDay = newFocused;
              },
            ),
          ),
        ),
      );

      // Verify header chevrons are present
      final leftChevron = find.byIcon(Icons.chevron_left);
      final rightChevron = find.byIcon(Icons.chevron_right);
      expect(leftChevron, findsOneWidget);
      expect(rightChevron, findsOneWidget);

      // Tap right chevron
      await tester.tap(rightChevron);
      await tester.pumpAndSettle();

      // Page should have navigated forward
      expect(focusedDay.isAfter(DateTime.utc(2026, 10, 21)), isTrue);

      // Tap left chevron
      await tester.tap(leftChevron);
      await tester.pumpAndSettle();
      expect(isSameDay(focusedDay, DateTime.utc(2026, 10, 21)), isTrue);
    });

    testWidgets('Horizontal swipe navigates weeks in week format', (tester) async {
      DateTime focusedDay = DateTime.utc(2026, 10, 21);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableCalendar<dynamic>(
              firstDay: DateTime.utc(2022, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              calendarFormat: CalendarFormat.week,
              availableCalendarFormats: const {
                CalendarFormat.week: 'Week',
              },
              availableGestures: AvailableGestures.horizontalSwipe,
              pageAnimationEnabled: false,
              onPageChanged: (newFocused) {
                focusedDay = newFocused;
              },
            ),
          ),
        ),
      );

      // Swipe horizontally on the visible day cell (next week)
      await tester.fling(find.text('21'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(focusedDay.isAfter(DateTime.utc(2026, 10, 21)), isTrue);
    });

    testWidgets('Tapping visible day selects day without jumping page', (tester) async {
      DateTime focusedDay = DateTime.utc(2026, 10, 21);
      DateTime? selectedDay = focusedDay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TableCalendar<dynamic>(
                  firstDay: DateTime.utc(2022, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  calendarFormat: CalendarFormat.week,
                  availableCalendarFormats: const {
                    CalendarFormat.week: 'Week',
                  },
                  availableGestures: AvailableGestures.horizontalSwipe,
                  pageAnimationEnabled: false,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: (newSelected, newFocused) {
                    setState(() {
                      selectedDay = newSelected;
                      // Do NOT change focusedDay if already visible!
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap on day 22 (Thursday)
      final day22 = find.text('22');
      expect(day22, findsOneWidget);

      await tester.tap(day22);
      await tester.pumpAndSettle();

      expect(selectedDay?.day, 22);
      // focusedDay stayed on 21 without jumping page
      expect(focusedDay.day, 21);
    });
  });
}
