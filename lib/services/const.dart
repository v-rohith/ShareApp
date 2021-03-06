import 'dart:ui';

final primaryColor = Color.fromARGB(255, 6, 111, 108);
final coolerWhite = Color(0xffFEFEFF);
final greyColor = Color(0xffaeaeae);
final greyColor2 = Color(0xffE8E8E8);
final dialogBorderRadius = 12.0;
final appBorderRadius = 3.0;
final appFont = 'Quicksand';
final String fromRentersTabText = 'From renters';
final String fromOwnersTabText = 'From owners';

enum RentalPhase {
  requesting,
  upcoming,
  current,
  past,
}

enum ReviewType {
  fromRenters,
  fromOwners,
}
