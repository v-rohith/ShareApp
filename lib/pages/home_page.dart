import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shareapp/main.dart';
import 'package:shareapp/models/item.dart';
import 'package:shareapp/models/user_edit.dart';
import 'package:shareapp/pages/item_detail.dart';
import 'package:shareapp/pages/item_edit.dart';
import 'package:shareapp/pages/profile_edit.dart';
import 'package:shareapp/rentals/chat.dart';
import 'package:shareapp/rentals/rental_detail.dart';
import 'package:shareapp/services/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:shareapp/extras/helpers.dart';

class HomePage extends StatefulWidget {
  static const routeName = '/homePage';

  BaseAuth auth;
  FirebaseUser firebaseUser;
  VoidCallback onSignOut;

  HomePage({this.auth, this.firebaseUser, this.onSignOut});

  @override
  State<StatefulWidget> createState() {
    return HomePageState();
  }
}

class HomePageState extends State<HomePage> {
  SharedPreferences prefs;
  String userID;
  List<Item> itemList;

  List bottomNavBarTiles;
  List bottomTabPages;
  int currentTabIndex;
  bool isLoading;

  EdgeInsets edgeInset;
  double padding;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    currentTabIndex = 0;

    bottomNavBarTiles = <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: Icon(Icons.search), title: Text('Search')),
      BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart), title: Text('Rentals')),
      BottomNavigationBarItem(
          icon: Icon(Icons.style), title: Text('My Listings')),
      BottomNavigationBarItem(icon: Icon(Icons.forum), title: Text('Messages')),
      BottomNavigationBarItem(
          icon: Icon(Icons.account_circle), title: Text('Profile')),
    ];

    padding = 18;
    edgeInset = EdgeInsets.only(
        left: padding, right: padding, bottom: padding, top: 30);

    userID = widget.firebaseUser.uid;

    setPrefs();
    handleInitUser();
  }

  void setPrefs() async {
    prefs = await SharedPreferences.getInstance();
    await prefs.setString('userID', userID);
  }

  void handleInitUser() async {
    isLoading = true;
    // get user object from firestore
    Firestore.instance
        .collection('users')
        .document(userID)
        .get()
        .then((DocumentSnapshot ds) {
      // if user is not in database, create user
      if (!ds.exists) {
        Firestore.instance.collection('users').document(userID).setData({
          'name': widget.firebaseUser.displayName ?? 'new user $userID',
          'avatar': widget.firebaseUser.photoUrl ?? 'https://bit.ly/2vcmALY',
          'email': widget.firebaseUser.email,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
          'creationDate': widget.firebaseUser.metadata.creationTimestamp,
        });
      }

      // if user is already in db
      else {
        //Firestore.instance.collection('users').document(userID).updateData({});
      }
    });

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Firestore.instance
        .collection('users')
        .document(userID)
        .get()
        .then((DocumentSnapshot ds) {
      Firestore.instance.collection('users').document(userID).updateData({
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
    });

    bottomTabPages = <Widget>[
      searchPage(),
      //homeTabPage(),
      myRentalsPage(),
      //myListingsTabPage(),
      myListingsPage(),
      messagesTabPage(),
      profileTabPage(),
    ];

    assert(bottomTabPages.length == bottomNavBarTiles.length);

    return Scaffold(
      body: isLoading
          ? Container(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Center(child: CircularProgressIndicator())
                  ]),
            )
          : IndexedStack(
              index: currentTabIndex,
              children: bottomTabPages,
            ),
      floatingActionButton: showFAB(),
      bottomNavigationBar: BottomNavigationBar(
        items: bottomNavBarTiles,
        currentIndex: currentTabIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (int index) {
          setState(() {
            currentTabIndex = index;
          });
        },
      ),
    );
  }

  RaisedButton showFAB() {
    return currentTabIndex == 2
        ? RaisedButton(
            onPressed: () {
              navigateToEdit(
                Item(
                  id: null,
                  status: true,
                  creator:
                      Firestore.instance.collection('users').document(userID),
                  name: '',
                  description: '',
                  type: null,
                  condition: null,
                  price: 0,
                  numImages: 0,
                  images: new List(),
                  location: null,
                  rental: null,
                ),
              );
            },
            child: Text("Add Item")
          )
        : null;
  }

  Widget cardItem(DocumentSnapshot ds) {
    CachedNetworkImage image = CachedNetworkImage(
      key: new ValueKey<String>(
          DateTime.now().millisecondsSinceEpoch.toString()),
      imageUrl: ds['images'][0],
      placeholder: (context, url) => new CircularProgressIndicator(),
    );
    return InkWell(onTap: () {
      navigateToDetail(ds.documentID);
    }, onLongPress: () {
      ds['rental'] == null ? deleteItemDialog(ds) : deleteItemError();
    }, child: new Container(child: new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      double h = constraints.maxHeight;
      double w = constraints.maxWidth;
      Icon icon = Icon(Icons.info_outline);
      switch (ds['type']) {
        case 'Tool':
          icon = Icon(
            Icons.build,
            size: h / 20,
          );
          break;
        case 'Leisure':
          icon = Icon(Icons.golf_course, size: h / 20);
          break;
        case 'Home':
          icon = Icon(Icons.home, size: h / 20);
          break;
        case 'Other':
          icon = Icon(Icons.device_unknown, size: h / 20);
          break;
      }
      return Column(
        children: <Widget>[
          Container(
              height: 2 * h / 3,
              width: w,
              child: FittedBox(fit: BoxFit.cover, child: image)),
          SizedBox(
            height: 10.0,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  icon,
                  SizedBox(
                    width: 5.0,
                  ),
                  ds['type'] != null
                      ? Text(
                          '${ds['type']}'.toUpperCase(),
                          style: TextStyle(
                              fontSize: h / 25,
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.bold),
                        )
                      : Text(''),
                ],
              ),
              Text(ds['name'],
                  style: TextStyle(
                      fontSize: h / 20,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold)),
              Text("\$${ds['price']} per day",
                  style: TextStyle(fontSize: h / 21, fontFamily: 'Quicksand')),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Container(
                    width: 5.0,
                  ),
                  Text(
                    "328",
                    style: TextStyle(
                      fontSize: h / 25,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              )
            ],
          ),
        ],
      );
    })));
  }

  Widget allUserItems(DocumentSnapshot ds) {
    CachedNetworkImage image = CachedNetworkImage(
      key: new ValueKey<String>(
          DateTime.now().millisecondsSinceEpoch.toString()),
      imageUrl: ds['images'][0],
      placeholder: (context, url) => new CircularProgressIndicator(),
    );
    return InkWell(onTap: () {
      navigateToDetail(ds.documentID);
    }, child: new Container(child: new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      double h = constraints.maxHeight;
      double w = constraints.maxWidth;
      Icon icon = Icon(Icons.info_outline);
      switch (ds['type']) {
        case 'Tool':
          icon = Icon(
            Icons.build,
            size: h / 20,
          );
          break;
        case 'Leisure':
          icon = Icon(Icons.golf_course, size: h / 20);
          break;
        case 'Home':
          icon = Icon(Icons.home, size: h / 20);
          break;
        case 'Other':
          icon = Icon(Icons.device_unknown, size: h / 20);
          break;
      }
      return Column(
        children: <Widget>[
          Container(
              height: 2 * h / 3,
              width: w,
              child: FittedBox(fit: BoxFit.cover, child: image)),
          SizedBox(
            height: 10.0,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  icon,
                  SizedBox(
                    width: 5.0,
                  ),
                  ds['type'] != null
                      ? Text(
                          '${ds['type']}'.toUpperCase(),
                          style: TextStyle(
                              fontSize: h / 25,
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.bold),
                        )
                      : Text(''),
                ],
              ),
              Text(ds['name'],
                  style: TextStyle(
                      fontSize: h / 20,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold)),
              Text("\$${ds['price']} per day",
                  style: TextStyle(fontSize: h / 21, fontFamily: 'Quicksand')),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Icon(
                    Icons.star_border,
                    size: h / 19,
                  ),
                  Container(
                    width: 5.0,
                  ),
                  Text(
                    "328",
                    style: TextStyle(
                      fontSize: h / 25,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              )
            ],
          ),
        ],
      );
    })));
  }

  Widget cardItemRentals(ds, ownerDS, rentalDS) {
    CachedNetworkImage image = CachedNetworkImage(
      key: new ValueKey<String>(
          DateTime.now().millisecondsSinceEpoch.toString()),
      imageUrl: ds['images'][0],
      placeholder: (context, url) => new CircularProgressIndicator(),
    );
    return new Container(child: new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      double h = constraints.maxHeight;
      double w = constraints.maxWidth;

      return InkWell(
        onTap: () {
          navigateToDetail(ds.documentID);
        },
        child: Column(
          children: <Widget>[
            Container(
                height: 1.5 * h / 3,
                width: w,
                child: FittedBox(fit: BoxFit.cover, child: image)),
            SizedBox(
              height: 10.0,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ds['type'] != null
                        ? Text(
                            '${ds['type']}'.toUpperCase(),
                            style: TextStyle(
                                fontSize: h / 25,
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.bold),
                          )
                        : Text(''),
                  ],
                ),
                Text('${ownerDS['name']}\'s ${ds['name']}',
                    style: TextStyle(
                        fontSize: h / 20,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.bold)),
                Text("\$${ds['price']} per day",
                    style:
                        TextStyle(fontSize: h / 21, fontFamily: 'Quicksand')),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.shopping_cart),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          RentalDetail.routeName,
                          arguments: RentalDetailArgs(
                            rentalDS.documentID,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.message),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          Chat.routeName,
                          arguments: ChatArgs(
                            rentalDS.documentID,
                          ),
                        );
                      },
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
      );
    }));
  }

  Widget searchPage() {
    return MediaQuery.removePadding(
      removeTop: true,
      context: context,
      child: ListView(
          physics: const ClampingScrollPhysics(),

       // shrinkWrap: true,
        children: <Widget>[
          introImageAndSearch(),
          SizedBox( height: 30.0,),
          categories(),
          divider(),
          lookingFor()
        ],
      ),
    );
  }
  
  Widget lookingFor(){
    double h = MediaQuery.of(context).size.height;
    Widget _searchItem(item, user, description){
      return Card(
        elevation: 0.7,
        child: ExpansionTile(
         title: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: <Widget>[
             Text(item, style: TextStyle(color: Colors.black),),
             Text(user, style: TextStyle(color: Colors.black),),
           ],
         ),
         trailing: Container(height: 0, width: 0),
         children: <Widget>[
          Container(padding: EdgeInsets.symmetric(horizontal: 10.0), child: Text(description, style: TextStyle(fontFamily: 'Quicksand'),)),
          Container(
            padding: EdgeInsets.only(right: 10.0),
            alignment: Alignment.bottomRight,
            child: IconButton(icon: Icon(Icons.chat_bubble_outline), onPressed: () => null,
            ),
          ),
         ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: h/55),
      child: Column(
        children: <Widget>[
            Container(
              alignment: Alignment.centerLeft, 
              child: Text("People Are Looking For...", style: TextStyle(fontFamily: 'Quicksand', fontSize: h/40, fontWeight: FontWeight.bold),)
            ),
            SizedBox(height: 10.0,),
            _searchItem("Keurig Coffee Maker", "Rohith", "I'm looking for a Keurig coffee maker because I have excess k-cups but no Keurig."),
            _searchItem("40\"+ TV", "Bob", "I'm hosting a football watching party this weekend. I need a big tv, preferably OLED and 4K Resolution."),
            _searchItem("Balloon Pump", "Trent", "Need a balloon pump to fill balloons. Manual pump."),
            Align(alignment: Alignment.bottomRight, child: FlatButton(child: Text("View all"), onPressed: null,),)
        ],
      ),
    );
  }

  Widget introImageAndSearch(){
    double h = MediaQuery.of(context).size.height;

    Widget _searchField() {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child: RaisedButton(
          elevation: 10.0,
          color: Colors.white,
          onPressed: () => print,
          child: Row(
            children: <Widget>[
              Icon(Icons.search),
              SizedBox( width: 10.0,),
              Text(
                "Try \"Basketball\"",
                style: TextStyle( fontFamily: 'Quicksand', fontWeight: FontWeight.w400),
              )
            ],
          ),
        ),
        height: h / 20,
      );
    }

    return Container(
      height: h/3,
      child: Stack(children: <Widget>[
        Container(height: h/3.2, child: SizedBox.expand(child: Image.asset('assets/surfing.jpg', fit: BoxFit.cover))),
        Container(height: h/3.2, color: Colors.black12),
        Align(
          alignment: Alignment.bottomCenter,
          child: _searchField()),
      ],),
    );
  }

  Widget categories() {
    double h = MediaQuery.of(context).size.height;

    Widget _categoryTile(category, image) {
      return InkWell(
        onTap: null,
        child: ClipRRect(
          borderRadius: new BorderRadius.circular(5.0),
          child: Container(
            height: h / 7.5,
            width: h / 7.5,
            child: Stack(
              children: <Widget>[
                SizedBox.expand(child: Image.asset(image, fit: BoxFit.cover)),
                SizedBox.expand( child: Container(color: Colors.black45),),
                Center( child: Text(category, style: TextStyle(color: Colors.white, fontFamily: 'Quicksand', fontSize: h/60)))
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: h / 55),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _categoryTile("Tools", 'assets/hammer.jpg'),
              _categoryTile("Leisure", 'assets/golfclub.jpg'),
              _categoryTile("Household", 'assets/coffee.jpg'),
            ],
          ),
          SizedBox(
            height: 15.0,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _categoryTile("Equipment", 'assets/lawnmower.jpg'),
              _categoryTile("Miscellaneous", 'assets/lawnchair.jpg'),
              _categoryTile("More", 'assets/misc.jpg'),
            ],
          ),
        ],
      ),
    );
  }

  Widget homeTabPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
      //  searchField(),
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: Text("Items near you",
              style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.bold,
                  fontSize: 30.0)),
        ),
        buildItemList('all'),
      ],
    );
  }

  Widget myRentalsPage() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: "renting"),
              Tab(text: "requesting"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: <Widget>[
                buildRentalsList(true),
              ],
            ),
            Column(
              children: <Widget>[
                buildRentalsList(false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget reusableObjList(String heading, displayList) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              heading,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.grey[350],
              border: Border.all(
                color: Colors.black,
                width: 2,
              ),
            ),
          ),
          Container(
            height: 12,
          ),
          displayList,
        ],
      ),
    );
  }

  Widget buildItemList([type = 'all', bool status]) {
    CollectionReference collectionReference =
        Firestore.instance.collection('items');
    int tilerows = MediaQuery.of(context).size.width > 500 ? 3 : 2;
    Stream stream = collectionReference.snapshots();
    if (type == 'listings') {
      stream = collectionReference
          .where('creator',
              isEqualTo:
                  Firestore.instance.collection('users').document(userID))
          .snapshots();
    }
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return new Text('${snapshot.error}');
          }
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:

            default:
              if (snapshot.hasData) {
                List<DocumentSnapshot> items = snapshot.data.documents.toList();
                return GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: tilerows,
                    childAspectRatio: (2 / 3),
                    padding: const EdgeInsets.all(20.0),
//                  mainAxisSpacing: 10.0,
                    crossAxisSpacing: MediaQuery.of(context).size.width / 15,
                    children: items
                        .map((DocumentSnapshot ds) => type == 'listings'
                            ? allUserItems(ds)
                            : cardItem(ds))
                        .toList());
              } else {
                return Container();
              }
          }
        },
      ),
    );
  }

  Widget myListingsPage() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: "all items"),
              Tab(text: "transactions"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: <Widget>[
                buildItemList('listings'),
              ],
            ),
            Column(
              children: <Widget>[
                reusableCategory("REQUESTS"),
                reusableCategory("UPCOMING"),
                reusableCategory("CURRENT"),
                reusableCategory("PAST"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget messagesTabPage() {
    double h = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.only(top: h/15, left: 30.0),
      child: Column(
        children: <Widget>[
          Align(alignment: Alignment.topLeft, child: Text("Messages", style: TextStyle(fontSize: 30.0, fontFamily: 'Quicksand'))),
          buildMessagesList(),
        ],
      ),
    );
  }

  Widget profileTabPage() {
    return Padding(
      padding: edgeInset,
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(10.0),
          ),
          profileIntroStream(),
          Divider(),
          profileTabAfterIntro(),
        ],
      ),
    );
  }

  Widget profileIntroStream() {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          Firestore.instance.collection('users').document(userID).snapshots(),
      builder:
          (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return new Text('${snapshot.error}');
        }
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:

          default:
            if (snapshot.hasData) {
              DocumentSnapshot ds = snapshot.data;
              return new Container(
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.only(left: 15.0),
                      alignment: Alignment.topLeft,
                      height: 60.0,
                      child: ClipOval(
                        child: CachedNetworkImage(
                          key: new ValueKey<String>(
                              DateTime.now().millisecondsSinceEpoch.toString()),
                          imageUrl: ds['avatar'],
                          placeholder: (context, url) => new Container(),
                        ),
                      ),
                    ),
                    Container(
                        padding: const EdgeInsets.only(top: 8.0, left: 15.0),
                        alignment: Alignment.centerLeft,
                        child: Text('${ds['name']}',
                            style: TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Quicksand'))),
                    Container(
                        padding: const EdgeInsets.only(top: 4.0, left: 15.0),
                        alignment: Alignment.centerLeft,
                        child: Text('${ds['email']}',
                            style: TextStyle(
                                fontSize: 15.0, fontFamily: 'Quicksand'))),
                    Container(
                        alignment: Alignment.centerLeft,
                        child: FlatButton(
                          child: Text("Edit Profile",
                              style: TextStyle(
                                  color: Color(0xff007f6e),
                                  fontFamily: 'Quicksand')),
                          onPressed: () => navToProfileEdit(),
                        )),
                  ],
                ),
              );
            } else {
              return Container();
            }
        }
      },
    );
  }

  Widget profileIntro() {
    return FutureBuilder(
      future: Firestore.instance.collection('users').document(userID).get(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          DocumentSnapshot ds = snapshot.data;
          return new Container(
            child: Column(
              children: <Widget>[
                // User Icon
                Container(
                  padding: EdgeInsets.only(left: 15.0),
                  alignment: Alignment.topLeft,
                  height: 60.0,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      key: new ValueKey<String>(
                          DateTime.now().millisecondsSinceEpoch.toString()),
                      imageUrl: ds['avatar'],
                      placeholder: (context, url) => new Container(),
                    ),
                  ),
                ),
                // username
                Container(
                    padding: const EdgeInsets.only(top: 8.0, left: 15.0),
                    alignment: Alignment.centerLeft,
                    child: Text('${ds['name']}',
                        style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Quicksand'))),
                // email
                Container(
                    padding: const EdgeInsets.only(top: 4.0, left: 15.0),
                    alignment: Alignment.centerLeft,
                    child: Text('${ds['email']}',
                        style: TextStyle(
                            fontSize: 15.0, fontFamily: 'Quicksand'))),
                //
                Container(
                    alignment: Alignment.centerLeft,
                    child: FlatButton(
                      child: Text("Edit Profile",
                          style: TextStyle(
                              color: Color(0xff007f6e),
                              fontFamily: 'Quicksand')),
                      onPressed: () => navToProfileEdit(),
                    )),
              ],
            ),
          );
        } else {
          return Container();
        }
      },
    );
  }

  Widget profileTabAfterIntro() {
    // [TEMPORARY SOLUTION]
    double height = (MediaQuery.of(context).size.height) - 335;
    return Container(
      height: height,
      child: MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            /// I'll remove this later, I'm just using it to quickly switch accounts
            reusableCategory("ACCOUNT SETTINGS"),
            reusableFlatButton(
                "Personal information", Icons.person_outline, null),
            reusableFlatButton("Payments and payouts", Icons.payment, null),
            reusableFlatButton("Notifications", Icons.notifications, null),
            reusableCategory("SUPPORT"),
            reusableFlatButton("Get help", Icons.help_outline, null),
            reusableFlatButton("Give us feedback", Icons.feedback, null),
            reusableFlatButton("Log out", null, logout),
            getProfileDetails()
          ],
        ),
      ),
    );
  }

  Widget reusableCategory(text) {
    return Container(
        padding: EdgeInsets.only(left: 15.0, top: 10.0),
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w100)));
  }

  Widget reusableFlatButton(text, icon, action) {
    return Column(
      children: <Widget>[
        Container(
          child: FlatButton(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(text, style: TextStyle(fontFamily: 'Quicksand')),
                Icon(icon)
              ],
            ),
            onPressed: () => action(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 15.0,
            right: 15.0,
          ),
          child: Divider(),
        )
      ],
    );
  }

  Widget getProfileDetails() {
    return FutureBuilder(
      future: Firestore.instance.collection('users').document(userID).get(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          DocumentSnapshot ds = snapshot.data;
          List<String> details = new List();
          details.add(ds.documentID);
          details.add(ds['email']);
          var date1 =
              new DateTime.fromMillisecondsSinceEpoch(ds['creationDate']);
          details.add(date1.toString());

          var date2 = new DateTime.fromMillisecondsSinceEpoch(ds['lastActive']);
          details.add(date2.toString());
          return Column(
            children: <Widget>[
              Container(
                height: 15,
              ),
              Text('User ID: ${details[0]}',
                  style: TextStyle(
                      color: Colors.black54,
                      fontFamily: 'Quicksand',
                      fontSize: 13.0)),
              Container(
                height: 15,
              ),
              Text('Account creation: ${details[2]}',
                  style: TextStyle(
                      color: Colors.black54,
                      fontFamily: 'Quicksand',
                      fontSize: 13.0)),
              Container(
                height: 15,
              ),
              Text(
                'Last active: ${details[3]}',
                style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Quicksand',
                    fontSize: 13.0),
              ),
            ],
          );
        } else {
          return Container();
        }
      },
    );
  }

  Widget buildRentalsList(bool requesting) {
    CollectionReference collectionReference =
        Firestore.instance.collection('users');
    int tilerows = MediaQuery.of(context).size.width > 500 ? 3 : 2;
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: collectionReference
            .document(userID)
            .collection('rentals')
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return new Text('${snapshot.error}');
          }
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:

            default:
              if (snapshot.hasData) {
                List<DocumentSnapshot> items = snapshot.data.documents.toList();
                return GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: tilerows,
                    childAspectRatio: (2 / 3),
                    crossAxisSpacing: MediaQuery.of(context).size.width / 15,
                    children: items.map((DocumentSnapshot userRentalDS) {
                      DocumentReference rentalDR = userRentalDS['rental'];

                      return StreamBuilder<DocumentSnapshot>(
                        stream: rentalDR.snapshots(),
                        builder: (BuildContext context,
                            AsyncSnapshot<DocumentSnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return new Text('${snapshot.error}');
                          }
                          switch (snapshot.connectionState) {
                            case ConnectionState.waiting:

                            default:
                              if (snapshot.hasData) {
                                DocumentSnapshot rentalDS = snapshot.data;
                                DocumentReference itemDR = rentalDS['item'];
                                DocumentReference renterDR = rentalDS['renter'];

                                if (userID == renterDR.documentID) {
                                  return StreamBuilder<DocumentSnapshot>(
                                    stream: itemDR.snapshots(),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<DocumentSnapshot>
                                            snapshot) {
                                      if (snapshot.hasError) {
                                        return new Text('${snapshot.error}');
                                      }
                                      switch (snapshot.connectionState) {
                                        case ConnectionState.waiting:

                                        default:
                                          if (snapshot.hasData) {
                                            DocumentSnapshot itemDS =
                                                snapshot.data;
                                            DocumentReference ownerDR =
                                                itemDS['creator'];

                                            if (requesting ^
                                                (rentalDS['status'] == 1)) {
                                              return StreamBuilder<
                                                  DocumentSnapshot>(
                                                stream: ownerDR.snapshots(),
                                                builder: (BuildContext context,
                                                    AsyncSnapshot<
                                                            DocumentSnapshot>
                                                        snapshot) {
                                                  if (snapshot.hasError) {
                                                    return new Text(
                                                        '${snapshot.error}');
                                                  }
                                                  switch (snapshot
                                                      .connectionState) {
                                                    case ConnectionState
                                                        .waiting:

                                                    default:
                                                      if (snapshot.hasData) {
                                                        DocumentSnapshot
                                                            ownerDS =
                                                            snapshot.data;

                                                        String created = 'Created: ' +
                                                            timeago.format(DateTime
                                                                .fromMillisecondsSinceEpoch(
                                                                    rentalDS[
                                                                        'created']));

                                                        return cardItemRentals(
                                                            itemDS,
                                                            ownerDS,
                                                            rentalDS);
                                                      } else {
                                                        return Container();
                                                      }
                                                  }
                                                },
                                              );
                                            } else {
                                              return Container();
                                            }
                                          } else {
                                            return Container();
                                          }
                                      }
                                    },
                                  );
                                } else {
                                  return Container();
                                }
                              } else {
                                return Container();
                              }
                          }
                        },
                      );
                    }).toList());
              } else {
                return Container();
              }
          }
        },
      ),
    );
  }

  Widget buildMessagesList() {
    CollectionReference collectionReference =
        Firestore.instance.collection('users');
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: collectionReference
            .document(userID)
            .collection('rentals')
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:

            default:
              if (snapshot.hasData) {
                return new ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data.documents.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot userRentalDS =
                        snapshot.data.documents[index];
                    DocumentReference otherUserDR = userRentalDS['otherUser'];
                    DocumentReference rentalDR = userRentalDS['rental'];

                    return StreamBuilder<DocumentSnapshot>(
                      stream: otherUserDR.snapshots(),
                      builder: (BuildContext context,
                          AsyncSnapshot<DocumentSnapshot> snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:

                          default:
                            if (snapshot.hasData) {
                              DocumentSnapshot otherUserDS = snapshot.data;

                              return StreamBuilder<DocumentSnapshot>(
                                stream: rentalDR.snapshots(),
                                builder: (BuildContext context,
                                    AsyncSnapshot<DocumentSnapshot> snapshot) {
                                  switch (snapshot.connectionState) {
                                    case ConnectionState.waiting:

                                    default:
                                      if (snapshot.hasData) {
                                        DocumentSnapshot rentalDS =
                                            snapshot.data;
                                        DocumentReference itemDR =
                                            rentalDS['item'];
                                        DocumentReference chatDR =
                                            rentalDS['chat'];

                                        return StreamBuilder<DocumentSnapshot>(
                                          stream: itemDR.snapshots(),
                                          builder: (BuildContext context,
                                              AsyncSnapshot<DocumentSnapshot>
                                                  snapshot) {
                                            if (snapshot.hasError) {
                                              return new Text(
                                                  '${snapshot.error}');
                                            }
                                            switch (snapshot.connectionState) {
                                              case ConnectionState.waiting:

                                              default:
                                                if (snapshot.hasData) {
                                                  DocumentSnapshot itemDS =
                                                      snapshot.data;

                                                  return StreamBuilder<
                                                      QuerySnapshot>(
                                                    stream: Firestore.instance
                                                        .collection('rentals')
                                                        .document(
                                                            rentalDS.documentID)
                                                        .collection('chat')
                                                        .orderBy('timestamp',
                                                            descending: true)
                                                        .limit(1)
                                                        .snapshots(),
                                                    builder: (BuildContext
                                                            context,
                                                        AsyncSnapshot<
                                                                QuerySnapshot>
                                                            snapshot) {
                                                      switch (snapshot
                                                          .connectionState) {
                                                        case ConnectionState
                                                            .waiting:

                                                        default:
                                                          if (snapshot .hasData) {
                                                            DocumentSnapshot lastMessageDS = snapshot.data .documents[0];
                                                            Text title = Text( otherUserDS['name'], style: TextStyle( fontWeight: FontWeight.bold, fontFamily: 'Quicksand'),);
                                                            Text lastActive = Text(('Last seen: ' + timeago.format(DateTime .fromMillisecondsSinceEpoch( otherUserDS[ 'lastActive']))), style: TextStyle(fontFamily: 'Quicksand',));
                                                            Text itemName = Text('Item: ${itemDS['name']}', style: TextStyle(fontFamily: 'Quicksand'));
                                                            String imageURL = otherUserDS[ 'avatar'];
                                                            String lastMessage = lastMessageDS[ 'content'];
                                                            int cutoff = 30;
                                                            String lastMessageCrop;

                                                            if (lastMessage .length > cutoff) {
                                                              lastMessageCrop = lastMessage.substring( 0, cutoff);
                                                              lastMessageCrop += '...';
                                                            } else {
                                                              lastMessageCrop = lastMessage;
                                                            }

                                                            return ListTile(
                                                              leading: Container(
                                                                height: 50,
                                                                child: ClipOval(
                                                                  child: CachedNetworkImage(
                                                                    key: new ValueKey< String>(DateTime .now() .millisecondsSinceEpoch .toString()),
                                                                    imageUrl: imageURL,
                                                                    placeholder: (context, url) => new Container(),
                                                                  ),
                                                                ),
                                                              ),
                                                              title: title,
                                                              subtitle: Container(
                                                                alignment: Alignment.centerLeft,
                                                                child: Column(children: <Widget>[
                                                                  Align(alignment: Alignment.centerLeft, child: lastActive),
                                                                  Align(alignment: Alignment.centerLeft, child: itemName),
                                                                  Align(alignment: Alignment.centerLeft, child: Text(lastMessageCrop, style: TextStyle(fontFamily: "Quicksand"),)),
                                                                ],),
                                                              ),
                                                              //subtitle: Text( '$lastActive\n$itemName\n$lastMessageCrop'),
                                                              onTap: () {
                                                                Navigator .pushNamed( context, Chat.routeName, arguments: ChatArgs( userRentalDS .documentID,),);
                                                              },
                                                            );
                                                          } else {
                                                            return Container();
                                                          }
                                                      }
                                                    },
                                                  );
                                                } else {
                                                  return Container();
                                                }
                                            }
                                          },
                                        );
                                      } else {
                                        return Container();
                                      }
                                  }
                                },
                              );
                            } else {
                              return Container();
                            }
                        }
                      },
                    );
                  },
                );
              } else {
                return Container();
              }
          }
        },
      ),
    );
  }

  void navigateToEdit(Item newItem) async {
    Navigator.pushNamed(
      context,
      ItemEdit.routeName,
      arguments: ItemEditArgs(
        newItem,
      ),
    );
  }

  void navigateToDetail(String itemID) async {
    Navigator.pushNamed(
      context,
      ItemDetail.routeName,
      arguments: ItemDetailArgs(
        itemID,
      ),
    );
  }

  Future<UserEdit> getUserEdit() async {
    UserEdit out;
    DocumentSnapshot ds =
        await Firestore.instance.collection('users').document(userID).get();
    if (ds != null) {
      out = new UserEdit(
          id: userID, photoUrl: ds['avatar'], displayName: ds['name']);
    }

    return out;
  }

  void navToProfileEdit() async {
    UserEdit userEdit = await getUserEdit();

    UserEdit result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => ProfileEdit(
                userEdit: userEdit,
              ),
          fullscreenDialog: true,
        ));

    if (result != null) {
      Firestore.instance.collection('users').document(userID).updateData({
        'name': result.displayName,
        'avatar': result.photoUrl,
      });
    }
  }

  Future<bool> deleteItemError() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text(
                  'Item is currently being rented, so it cannot be deleted'),
              actions: <Widget>[
                FlatButton(
                  child: const Text('Ok'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    // Pops the confirmation dialog but not the page.
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> deleteItemDialog(DocumentSnapshot ds) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Delete item?'),
              content: Text('${ds['name']}'),
              actions: <Widget>[
                FlatButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(
                        false); // Pops the confirmation dialog but not the page.
                  },
                ),
                FlatButton(
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    deleteItem(ds);
                    // Pops the confirmation dialog but not the page.
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void deleteItem(DocumentSnapshot ds) {
    DocumentReference documentReference = ds.reference;
    Firestore.instance.collection('users').document(userID).updateData({
      'items': FieldValue.arrayRemove([documentReference])
    });

    deleteImages(ds.documentID, ds['numImages']);
    Firestore.instance.collection('items').document(ds.documentID).delete();
  }

  void deleteImages(String id, int numImages) async {
    for (int i = 0; i < numImages; i++) {
      FirebaseStorage.instance.ref().child('$id/$i').delete();
    }

    FirebaseStorage.instance.ref().child('$id').delete();
  }

  void goToLastScreen() {
    Navigator.pop(context);
  }

  Future<DocumentSnapshot> getUserFromFirestore(String userID) async {
    DocumentSnapshot ds =
        await Firestore.instance.collection('users').document(userID).get();

    return ds;
  }

  void logout() async {
    try {
      await widget.auth.signOut();
      widget.onSignOut();
    } catch (e) {
      print(e);
    }
  }
}

void showSnackBar(BuildContext context, String item) {
  var message = SnackBar(
    content: Text("$item was pressed"),
    action: SnackBarAction(
        label: "Undo",
        onPressed: () {
          // do something
        }),
  );

  Scaffold.of(context).showSnackBar(message);
}

Widget template() {
  // template
  return StreamBuilder<DocumentSnapshot>(
    stream: null,
    builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
      if (snapshot.hasError) {
        return new Text('${snapshot.error}');
      }
      switch (snapshot.connectionState) {
        case ConnectionState.waiting:
          return Center(
            child: new Container(),
          );
        default:
          if (snapshot.hasData) {
            DocumentSnapshot ds = snapshot.data;
          } else {
            return Container();
          }
      }
    },
  );
}

// to show all items created by you
//where('creator', isEqualTo: Firestore.instance.collection('users').document(userID)),

/*
  Widget buildRentalsListOLD(bool requesting) {
    CollectionReference collectionReference =
        Firestore.instance.collection('users');
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: collectionReference
            .document(userID)
            .collection('rentals')
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return new Text('${snapshot.error}');
          }
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:

            default:
              if (snapshot.hasData) {
                return new ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data.documents.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot userRentalDS =
                        snapshot.data.documents[index];
                    DocumentReference rentalDR = userRentalDS['rental'];

                    return StreamBuilder<DocumentSnapshot>(
                      stream: rentalDR.snapshots(),
                      builder: (BuildContext context,
                          AsyncSnapshot<DocumentSnapshot> snapshot) {
                        if (snapshot.hasError) {
                          return new Text('${snapshot.error}');
                        }
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:

                          default:
                            if (snapshot.hasData) {
                              DocumentSnapshot rentalDS = snapshot.data;
                              DocumentReference itemDR = rentalDS['item'];
                              DocumentReference renterDR = rentalDS['renter'];

                              if (userID == renterDR.documentID) {
                                return StreamBuilder<DocumentSnapshot>(
                                  stream: itemDR.snapshots(),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<DocumentSnapshot>
                                          snapshot) {
                                    if (snapshot.hasError) {
                                      return new Text('${snapshot.error}');
                                    }
                                    switch (snapshot.connectionState) {
                                      case ConnectionState.waiting:

                                      default:
                                        if (snapshot.hasData) {
                                          DocumentSnapshot itemDS =
                                              snapshot.data;
                                          DocumentReference ownerDR =
                                              itemDS['creator'];

                                          if (requesting ^
                                              (rentalDS['status'] == 1)) {
                                            return StreamBuilder<
                                                DocumentSnapshot>(
                                              stream: ownerDR.snapshots(),
                                              builder: (BuildContext context,
                                                  AsyncSnapshot<
                                                          DocumentSnapshot>
                                                      snapshot) {
                                                if (snapshot.hasError) {
                                                  return new Text(
                                                      '${snapshot.error}');
                                                }
                                                switch (
                                                    snapshot.connectionState) {
                                                  case ConnectionState.waiting:

                                                  default:
                                                    if (snapshot.hasData) {
                                                      DocumentSnapshot ownerDS =
                                                          snapshot.data;

                                                      String created = 'Created: ' +
                                                          timeago.format(DateTime
                                                              .fromMillisecondsSinceEpoch(
                                                                  rentalDS[
                                                                      'created']));

                                                      return ListTile(
                                                        leading: Icon(Icons
                                                            .shopping_cart),
                                                        //leading: Icon(Icons.build),
                                                        title: Text(
                                                          '${ownerDS['name']}\'s ${itemDS['name']}',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        subtitle: Text(created),
                                                        onTap: () {
                                                          Navigator.pushNamed(
                                                            context,
                                                            RentalDetail
                                                                .routeName,
                                                            arguments:
                                                                RentalDetailArgs(
                                                              rentalDS
                                                                  .documentID,
                                                            ),
                                                          );
                                                        },
                                                        trailing: IconButton(
                                                          icon: Icon(
                                                              Icons.message),
                                                          onPressed: () {
                                                            Navigator.pushNamed(
                                                              context,
                                                              Chat.routeName,
                                                              arguments:
                                                                  ChatArgs(
                                                                rentalDS
                                                                    .documentID,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    } else {
                                                      return Container();
                                                    }
                                                }
                                              },
                                            );
                                          } else {
                                            return Container();
                                          }
                                        } else {
                                          return Container();
                                        }
                                    }
                                  },
                                );
                              } else {
                                return Container();
                              }
                            } else {
                              return Container();
                            }
                        }
                      },
                    );
                  },
                );
              } else {
                return Container();
              }
          }
        },
      ),
    );
  }*/
