import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shareapp/extras/helpers.dart';
import 'package:shareapp/main.dart';
import 'package:shareapp/models/item.dart';
import 'package:shareapp/pages/all_reviews.dart';
import 'package:shareapp/pages/item_edit.dart';
import 'package:shareapp/pages/profile_page.dart';
import 'package:shareapp/rentals/chat.dart';
import 'package:shareapp/rentals/rental_calendar.dart';
import 'package:shareapp/services/const.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemDetail extends StatefulWidget {
  static const routeName = '/itemDetail';
  final DocumentSnapshot initItemDS;

  ItemDetail({Key key, this.initItemDS}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return ItemDetailState();
  }
}

class ItemDetailState extends State<ItemDetail> {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();

  GoogleMapController googleMapController;
  Map<CircleId, Circle> circles = <CircleId, Circle>{};
  GeoPoint itemLocationGeoPoint;
  Position currentLocation;
  String milesAway = 'Getting location...';

  String url;
  double padding = 5.0;

  DocumentSnapshot itemDS;
  SharedPreferences prefs;
  String myUserID;
  String itemCreator;
  String itemOwnerID;
  List recentReviews = [];
  Map owner;

  bool isAuthenticated;
  bool isLoading = true;
  bool isOwner;
  bool isVisible;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    itemDS = widget.initItemDS;

    getMyUserID();
  }

  void delayPage() async {
    Future.delayed(Duration(milliseconds: 750)).then((_) {
      setState(() {
        isLoading = false;
      });
    });
  }

  void getMyUserID() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();

    if (user != null) {
      isAuthenticated = true;
      myUserID = user.uid;
    } else {
      isAuthenticated = false;
    }

    getSnapshots(false);
  }

  getUserLocation() async {
    GeolocationStatus geolocationStatus =
        await Geolocator().checkGeolocationPermissionStatus();

    if (geolocationStatus != null) {
      if (geolocationStatus == GeolocationStatus.granted) {
        currentLocation = await locateUser();

        if (currentLocation != null) {
          double distanceInMeters = await Geolocator().distanceBetween(
            currentLocation.latitude,
            currentLocation.longitude,
            itemLocationGeoPoint.latitude,
            itemLocationGeoPoint.longitude,
          );

          double distanceInMiles = distanceInMeters / 1609.344;
          milesAway = '${distanceInMiles.toStringAsFixed(1)} miles away';
          setState(() {});
        }
      } else {
        milesAway = 'No location data';
        setState(() {});
      }
    }
  }

  Future<Position> locateUser() async {
    return Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<Null> getSnapshots(bool refreshItemDS) async {
    DocumentSnapshot ds = refreshItemDS
        ? await Firestore.instance
            .collection('items')
            .document(itemDS.documentID)
            .get()
        : itemDS;

    if (ds != null) {
      itemDS = ds;

      DocumentReference dr = itemDS['creator'];
      itemOwnerID = dr.documentID;

      owner = itemDS['owner'];
      isOwner = myUserID == itemOwnerID ? true : false;
      isVisible = itemDS['isVisible'];

      dr = itemDS['rental'];

      itemLocationGeoPoint = itemDS['location']['geopoint'];

      setCircle();
      getUserLocation();

      QuerySnapshot querySnapshot = await Firestore.instance
          .collection('rentals')
          .where('item',
              isEqualTo: Firestore.instance
                  .collection('items')
                  .document(itemDS.documentID))
          .where('ownerReviewSubmitted', isEqualTo: true)
          .orderBy('lastUpdateTime', descending: true)
          .limit(3)
          .getDocuments();
      List rentalSnapshots = querySnapshot.documents;

      if (rentalSnapshots != null && rentalSnapshots.isNotEmpty) {
        recentReviews = rentalSnapshots;
      }

      if (itemDS != null) {
        delayPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => getSnapshots(true),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : showBody(),
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.only(top: 120.0, left: 5.0),
        child: FloatingActionButton(
          heroTag: 'back',
          onPressed: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back),
          elevation: 1,
          backgroundColor: Colors.white70,
          foregroundColor: primaryColor,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
      bottomNavigationBar: isLoading
          ? Container(
              height: 0,
            )
          : bottomDetails(),
    );
  }

  Container bottomDetails() {
    return Container(
      height: 70.0,
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
          color: Colors.black12,
          offset: new Offset(0, -0.5),
        )
      ]),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: showItemPrice(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 30.0),
            child: checkAvailabilityButton(),
          )
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
    );
  }

  RaisedButton checkAvailabilityButton() {
    return RaisedButton(
        onPressed: () => navToRentalCalendar(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
        color: primaryColor,
        child: Text('Check Availability',
            style: TextStyle(color: Colors.white, fontFamily: 'Quicksand')));
  }

  Future<DocumentSnapshot> getItemFromFirestore() async {
    DocumentSnapshot ds = await Firestore.instance
        .collection('items')
        .document(itemDS.documentID)
        .get();

    return ds;
  }

  Widget showBody() {
    return ListView(
      padding: EdgeInsets.all(0),
      children: <Widget>[
        Stack(children: <Widget>[
          showItemImages(),
          Row(
            children: <Widget>[
              Spacer(),
              isOwner
                  ? Container(
                      padding: const EdgeInsets.only(top: 30.0, right: 5.0),
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: "edit",
                        onPressed: () => navigateToEdit(),
                        child: Icon(Icons.edit),
                        elevation: 0,
                        backgroundColor: Colors.white54,
                        foregroundColor: primaryColor,
                      ),
                    )
                  : Container(),
            ],
          ),
        ]),
        showItemType(),
        showItemName(),
        showItemCondition(),
        showItemCreator(),
        showItemDescription(),
        divider(),
        showItemLocation(),
        divider(),
        isOwner ? showItemVisibilityModifier() : Container(),
        showReviews(),
      ],
    );
  }

  Widget chatButton() {
    return Container(
       decoration: isOwner ? null :
        BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: primaryColor)
        ),
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: isOwner
          ? Container()
          : GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed(
                  Chat.routeName,
                  arguments: ChatArgs(itemOwnerID),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text("Chat", style: TextStyle(color: primaryColor, fontFamily: appFont, fontSize: 14.0, fontWeight: FontWeight.w400)),
                ],
              )),
    );
  }

  Widget showReviews() {
    if (recentReviews.isEmpty) {
      return Container();
    }

    double h = MediaQuery.of(context).size.height;
    List<Widget> reviews = [];

    recentReviews.forEach((var snap) {
      Map renter = snap['renterData'];
      Map customerReview = snap['ownerReview'];

      reviews.add(reviewTile(
          renter['avatar'],
          renter['name'],
          customerReview['overall'].toDouble(),
          customerReview['reviewNote'],
          snap['lastUpdateTime'].toDate()));
    });

    double rating = itemDS['rating'].toDouble();
    double numRatings = itemDS['numRatings'].toDouble();
    double itemRating = numRatings == 0 ? 0 : rating / numRatings;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Recent reviews',
                  style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Quicksand')),
              StarRating(rating: itemRating, sz: h / 30),
            ],
          ),
          SizedBox(
            height: 10.0,
          ),
          Column(children: reviews),
          Align(
              alignment: Alignment.bottomRight,
              child: InkWell(
                  onTap: () => navToAllReviews(),
                  child: Text('View All',
                      style: TextStyle(
                          fontFamily: 'Quicksand', color: primaryColor)))),
          Container(height: 10),
        ],
      ),
    );
  }

  Widget divider() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Divider(),
    );
  }

  Widget showItemCreator() {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: navToItemCreatorProfile,
          child: Padding(
            padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Shared by ${owner['name']}',
                  style: TextStyle(
                      color: Colors.black, fontSize: 15.0, fontFamily: 'Quicksand'),
                  textAlign: TextAlign.left,
                ),
                Container(
                  height: 50.0,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      //key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                      imageUrl: owner['avatar'],
                      placeholder: (context, url) =>
                          new CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 15, top: 7),
            child: isAuthenticated ? chatButton() : Container(color: Colors.pink),
          ),
        ),
      ],
    );
  }

  Widget showItemName() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: SizedBox(
          child: Container(
        color: Color(0x00000000),
        child: Text(
          '${itemDS['name']}',
          style: TextStyle(
              color: Colors.black,
              fontSize: 40.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand'),
          textAlign: TextAlign.left,
        ),
      )),
    );
  }

  Widget showItemPrice() {
    return SizedBox(
        //height: 50.0,
        child: Container(
      color: Color(0x00000000),
      child: Row(
        children: <Widget>[
          Text(
            '\$${itemDS['price']}',
            style: TextStyle(
                color: Colors.black,
                fontSize: 25.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Quicksand'),
          ),
          Text(
            ' / DAY',
            style: TextStyle(
                color: Colors.black, fontSize: 12.0, fontFamily: 'Quicksand'),
          )
        ],
      ),
    ));
  }

  Widget showItemDescription() {
    return Padding(
      padding: EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
      child: SizedBox(
          child: Container(
        color: Color(0x00000000),
        child: Text(
          '${itemDS['description']}',
          style: TextStyle(
              color: Colors.black, fontSize: 15.0, fontFamily: 'Quicksand'),
          textAlign: TextAlign.left,
        ),
      )),
    );
  }

  Widget showItemType() {
    return Padding(
      padding: EdgeInsets.only(left: 20.0, top: 20.0),
      child: SizedBox(
          child: Container(
        color: Color(0x00000000),
        child: Text(
          '${itemDS['type']}'.toUpperCase(),
          style: TextStyle(
              color: Colors.black54,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand'),
          textAlign: TextAlign.left,
        ),
      )),
    );
  }

  Widget showItemCondition() {
    return Padding(
      padding: EdgeInsets.only(left: 20.0, top: 5.0),
      child: SizedBox(
          child: Container(
        color: Color(0x00000000),
        child: Row(
          children: <Widget>[
            Text(
              'Condition: ',
              style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13.0,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Quicksand'),
              textAlign: TextAlign.left,
            ),
            Text(
              '${itemDS['condition']}',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 14.0,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Quicksand'),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      )),
    );
  }

  Widget showNumImages() {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: SizedBox(
          height: 50.0,
          child: Container(
            color: Color(0x00000000),
            child: Text(
              'Num images: ${itemDS['numImages']}',
              style: TextStyle(color: Colors.black, fontSize: 20.0),
              textAlign: TextAlign.left,
            ),
          )),
    );
  }

  Widget showItemImages() {
    double w = MediaQuery.of(context).size.width;
    List imagesList = itemDS['images'];
    return imagesList.length > 0
        ? Hero(
            tag: "${itemDS.documentID}",
            child: Container(
                height: w, width: w, child: getImagesListView(context)))
        : Text('No images yet\n');
  }

  void setCircle() async {
    final Circle circle = Circle(
      circleId: CircleId('0'),
      consumeTapEvents: false,
      strokeColor: Color.fromARGB(0, 60, 195, 254),
      //fillColor: Color(2),
      fillColor: Color.fromRGBO(60, 195, 254, 0.5),
      //strokeWidth: 5,
      center:
          LatLng(itemLocationGeoPoint.latitude, itemLocationGeoPoint.longitude),
      radius: 402,
      onTap: () {
        //_onCircleTapped(circleId);
      },
    );

    setState(() {
      circles[CircleId('0')] = circle;
    });
  }

  Widget showItemLocation() {
    double widthOfScreen = MediaQuery.of(context).size.width;

    Widget showMap() {
      return GoogleMap(
        mapType: MapType.normal,
        rotateGesturesEnabled: false,
        initialCameraPosition: CameraPosition(
          target: LatLng(
              itemLocationGeoPoint.latitude, itemLocationGeoPoint.longitude),
          zoom: 13,
          //zoom: 11,
        ),
        circles: Set<Circle>.of(circles.values),
        onMapCreated: (GoogleMapController controller) {
          googleMapController = controller;
        },
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
          Factory<OneSequenceGestureRecognizer>(
            () =>

                /// to enable dragging, use EagerGestureRecognizer()
                /// to disable dragging, use ScaleGestureRecognizer()
                EagerGestureRecognizer(),
            //ScaleGestureRecognizer(),
          ),
        ].toSet(),
      );
    }

    Widget showCircle() {
      double size = 125;

      return Center(
        child: Opacity(
          opacity: .5,
          child: Container(
            width: size,
            height: size,
            decoration: new BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
      child: Column(
        children: <Widget>[
          Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(bottom: 5.0),
            child: Text('The Location',
                style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Quicksand')),
          ),
          Container(
            padding: EdgeInsets.only(bottom: 10.0),
            alignment: Alignment.centerLeft,
            child: Text(milesAway, style: TextStyle(color: Colors.black, fontSize: 15.0, fontFamily: 'Quicksand'))),
          Center(
            child: SizedBox(
              width: widthOfScreen,
              height: 200.0,
              child: Stack(
                children: <Widget>[
                  showMap(),
                  //showCircle(),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 5.0),
              child: Text('* Exact pickup location to be agreed upon', style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.grey, fontFamily: 'Quicksand')),
            ),
          ),
        ],
      ),
    );
  }

  Widget showItemVisibilityModifier() {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text('Going on vacation? Uncheck the switch to prevent '
                'others from renting this item'),
          ),
          Switch(
            value: isVisible,
            onChanged: (value) {
              changeItemVisibility(value);
            },
          )
        ],
      ),
    );
  }

  void changeItemVisibility(bool value) async {
    setState(() {
      isVisible = value;
      isLoading = true;
    });

    Firestore.instance
        .collection('items')
        .document(itemDS.documentID)
        .updateData({'isVisible': value}).then((_) {
      setState(() {
        isLoading = false;
      });
    });
  }

  getImagesListView(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    List imagesList = itemDS['images'];
    return ListView.builder(
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      itemCount: imagesList.length,
      itemBuilder: (BuildContext context, int index) {
        return new Container(
          width: w,
          height: w,
          child: FittedBox(
            fit: BoxFit.cover,
            child: CachedNetworkImage(
              imageUrl: imagesList[index],
              placeholder: (context, url) => new CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  Widget sizedContainer(Widget child) {
    return new SizedBox(
      width: 300.0,
      height: 150.0,
      child: new Center(
        child: child,
      ),
    );
  }

  void navToAllReviews() async {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => AllReviews(
            itemDS: itemDS,
          ),
        ));
  }

  void navigateToEdit() async {
    Item editItem = Item.fromMap(itemDS.data);

    Item result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => ItemEdit(
            item: editItem,
            itemId: itemDS.documentID,
          ),
          fullscreenDialog: true,
        ));

    if (result != null) {
      setState(() {
        getSnapshots(true);
      });
    }
  }

  void navToRentalCalendar() async {
    getSnapshots(true).then(
      (_) {
        Navigator.pushNamed(
          context,
          RentalCalendar.routeName,
          arguments: RentalCalendarArgs(
            itemDS,
          ),
        );
      },
    );
  }

  Future<bool> showRequestErrorDialog() async {
    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
        theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

    String message = 'Someone has already requested this item!';

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text(
                message,
                style: dialogTextStyle,
              ),
              actions: <Widget>[
                FlatButton(
                  child: const Text('Ok'),
                  onPressed: () {
                    Navigator.of(context).pop(
                        false); // Pops the confirmation dialog but not the page.
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void navToItemCreatorProfile() {
    Navigator.pushNamed(
      context,
      ProfilePage.routeName,
      arguments: ProfilePageArgs(
        itemOwnerID,
      ),
    );
  }

  setCamera() async {
    GeoPoint gp = itemDS['location']['geopoint'];
    double lat = gp.latitude;
    double long = gp.longitude;

    LatLng newLoc = LatLng(lat, long);
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: newLoc, zoom: 11.5),
      ),
    );
  }

  void deleteItem() async {
    setState(() {
      isLoading = true;
    });

    Firestore.instance
        .collection('items')
        .document(itemDS.documentID)
        .delete()
        .then((_) => Navigator.of(context).pop());
  }

  void goToLastScreen() {
    Navigator.pop(context);
  }
}
