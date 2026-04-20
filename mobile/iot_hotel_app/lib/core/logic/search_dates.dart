import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchDates {
  final DateTime checkIn;
  final DateTime checkOut;

  SearchDates({required this.checkIn, required this.checkOut});

  int get nights => checkOut.difference(checkIn).inDays;

  SearchDates copyWith({DateTime? checkIn, DateTime? checkOut}) {
    return SearchDates(
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
    );
  }
}

class SearchDatesNotifier extends StateNotifier<SearchDates> {
  SearchDatesNotifier()
      : super(SearchDates(
          checkIn: DateTime.now().add(const Duration(days: 1)),
          checkOut: DateTime.now().add(const Duration(days: 2)),
        ));

  void updateDates(DateTime checkIn, DateTime checkOut) {
    state = SearchDates(checkIn: checkIn, checkOut: checkOut);
  }
}

final searchDatesProvider =
    StateNotifierProvider<SearchDatesNotifier, SearchDates>(
  (ref) => SearchDatesNotifier(),
);
