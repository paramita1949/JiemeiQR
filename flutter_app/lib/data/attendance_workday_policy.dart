bool isAttendanceDefinitelyRestDay(DateTime day, String weekendType) {
  if (weekendType == 'single') {
    return false;
  }
  return isAttendanceWeekend(day);
}

bool isAttendanceWeekday(DateTime day) {
  return day.weekday != DateTime.saturday && day.weekday != DateTime.sunday;
}

bool isAttendanceWeekend(DateTime day) {
  return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
}
