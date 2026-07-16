class DateTimeUtils {
  static String format(DateTime? value) {
    if (value == null) {
      return 'Нет данных';
    }

    return value.toLocal().toString();
  }
}