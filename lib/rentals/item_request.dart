import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shareapp/main.dart';
import 'package:flutter/material.dart';
import 'package:shareapp/rentals/chat.dart';
import 'package:shareapp/rentals/rental_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum DismissDialogAction {
  cancel,
  discard,
  save,
}

class ItemRequest extends StatefulWidget {
  static const routeName = '/requestItem';
  final String itemID;

  ItemRequest({Key key, this.itemID}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return ItemRequestState();
  }
}

/// We initially assume we are in editing mode
class ItemRequestState extends State<ItemRequest> {
  final GlobalKey<FormState> formKey = new GlobalKey<FormState>();
  SharedPreferences prefs;

  bool isUploading = false;
  bool isLoading;
  String myUserID;
  String photoURL;

  DocumentSnapshot itemDS;
  DocumentSnapshot creatorDS;
  Future<File> selectedImage;
  File imageFile;
  String message;
  String note;

  TextEditingController displayNameController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  FocusNode focusNode;

  DateTime startDateTime = DateTime.now().add(Duration(hours: 1));
  DateTime endDateTime = DateTime.now().add(Duration(hours: 2));

  TextStyle textStyle;
  TextStyle inputTextStyle;
  ThemeData theme;
  double padding = 5.0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    focusNode = FocusNode();
    getMyUserID();
    getSnapshots();
  }

  void getMyUserID() async {
    prefs = await SharedPreferences.getInstance();
    myUserID = prefs.getString('userID') ?? '';
  }

  void getSnapshots() async {
    isLoading = true;
    DocumentSnapshot ds = await Firestore.instance
        .collection('items')
        .document(widget.itemID)
        .get();

    if (ds != null) {
      itemDS = ds;

      DocumentReference dr = itemDS['creator'];
      String str = dr.documentID;

      ds = await Firestore.instance.collection('users').document(str).get();

      if (ds != null) {
        creatorDS = ds;
      }

      if (prefs != null && itemDS != null && creatorDS != null) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    theme = Theme.of(context);
    textStyle =
        Theme.of(context).textTheme.headline.merge(TextStyle(fontSize: 20));
    inputTextStyle = Theme.of(context).textTheme.subtitle;
    note = '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Item Request'),
        actions: <Widget>[
          FlatButton(
            child: Text('SEND',
                textScaleFactor: 1.05,
                style: theme.textTheme.body2.copyWith(color: Colors.white)),
            onPressed: () {
              sendItem();
            },
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          isLoading
              ? Container(
                  decoration:
                      new BoxDecoration(color: Colors.white.withOpacity(0.0)),
                )
              : showBody(),
          showCircularProgress(),
        ],
      ),
      bottomNavigationBar: Container(
        height: MediaQuery.of(context).size.height / 10,
        color: Colors.black,
        child: RaisedButton(
          child: Text("test"),
          onPressed: null,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget showBody() {
    return Padding(
      padding: EdgeInsets.all(15),
      child: ListView(
        children: <Widget>[
          showItemName(),
          showItemCreator(),
          Container(
            height: 10,
          ),
          showStartTimePicker(),
          showEndTimePicker(),
          showDuration(),
          Container(
            height: 10,
          ),
          showNoteEdit(),
        ],
      ),
    );
  }

  Widget showItemName() {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: SizedBox(
          height: 50.0,
          child: Container(
            color: Color(0x00000000),
            child: Text(
              'You\'re requesting a:\n${itemDS['name']}',
              //itemName,
              style: TextStyle(color: Colors.black, fontSize: 20.0),
              textAlign: TextAlign.left,
            ),
          )),
    );
  }

  Widget showItemCreator() {
    return FutureBuilder(
      future: itemDS['creator'].get(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          creatorDS = snapshot.data;

          return Row(
            children: <Widget>[
              Text(
                'You\'re requesting from:\n${creatorDS['displayName']}',
                style: TextStyle(color: Colors.black, fontSize: 20.0),
                textAlign: TextAlign.left,
              ),
              Expanded(
                child: Container(
                  height: 50,
                  child: CachedNetworkImage(
                    key: new ValueKey<String>(
                        DateTime.now().millisecondsSinceEpoch.toString()),
                    imageUrl: creatorDS['photoURL'],
                    placeholder: (context, url) =>
                        new CircularProgressIndicator(),
                  ),
                ),
              ),
            ],
          );
        } else {
          return Container(
            child: Text('\n\n'),
          );
        }
      },
    );
  }

  Widget showNoteEdit() {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: TextField(
        //keyboardType: TextInputType.multiline,
        focusNode: focusNode,
        maxLines: 3,
        controller: noteController,
        style: textStyle,
        onChanged: (value) {
          note = noteController.text;
        },
        decoration: InputDecoration(
          labelText: 'Add note (optional)',
          filled: true,
        ),
      ),
    );
  }

  Widget showStartTimePicker() {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Start', style: theme.textTheme.caption),
          DateTimeItem(
            dateTime: startDateTime,
            onChanged: (DateTime value) {
              setState(() {
                startDateTime = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget showEndTimePicker() {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('End', style: theme.textTheme.caption),
          DateTimeItem(
            dateTime: endDateTime,
            onChanged: (DateTime value) {
              setState(() {
                endDateTime = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget showDuration() {
    Duration durationTime = endDateTime.difference(startDateTime);
    String duration = durationTime.inHours.toString();

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Duration: ${duration} hours',
            style: TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget showCircularProgress() {
    if (isUploading) {
      return Container(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                "Sending...",
                style: TextStyle(fontSize: 30),
              ),
              Container(
                height: 20.0,
              ),
              Center(child: CircularProgressIndicator())
            ]),
      );
    } else {
      return Container(
        height: 0.0,
        width: 0.0,
      );
    }
  }

  void navToItemRental() async {
    setState(() {
      isUploading = true;
    });

    String rentalID;

    DocumentReference rentalDR =
        await Firestore.instance.collection("rentals").add({
      'status': 1, // set rental status to requested
      'item': Firestore.instance.collection('items').document(widget.itemID),
      'owner':
          Firestore.instance.collection('users').document(creatorDS.documentID),
      'renter': Firestore.instance.collection('users').document(myUserID),
      'start': startDateTime,
      'end': endDateTime,
      'created': DateTime.now().millisecondsSinceEpoch,
    });

    if (rentalDR != null) {
      rentalID = rentalDR.documentID;

      var myUserDR = Firestore.instance
          .collection('users')
          .document(myUserID)
          .collection('rentals')
          .document(rentalDR.documentID);

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          myUserDR,
          {
            'rental': rentalDR,
            'isRenter': true,
            'otherUser': Firestore.instance
                .collection('users')
                .document(creatorDS.documentID),
          },
        );
      });

      var creatorDR = Firestore.instance
          .collection('users')
          .document(creatorDS.documentID)
          .collection('rentals')
          .document(rentalDR.documentID);

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          creatorDR,
          {
            'rental': rentalDR,
            'isRenter': false,
            'otherUser':
                Firestore.instance.collection('users').document(myUserID),
          },
        );
      });

      /*
      Firestore.instance
          .collection('users')
          .document(myUserID)
          .updateData({'rentals': FieldValue.arrayUnion([rentalDR])});

      Firestore.instance
          .collection('users')
          .document(creatorDS.documentID)
          .updateData({'rentals': FieldValue.arrayUnion([rentalDR])});
          */

      Firestore.instance
          .collection('items')
          .document(widget.itemID)
          .updateData({
        'rental': Firestore.instance.collection('rentals').document(rentalID)
      });

      var dr = Firestore.instance
          .collection('rentals')
          .document(rentalID)
          .collection('chat')
          .document(DateTime.now().millisecondsSinceEpoch.toString());

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          dr,
          {
            'idFrom': myUserID,
            'idTo': creatorDS.documentID,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': message,
            'type': 0,
          },
        );
      });

      /*
      Firestore.instance.collection('rentals').document(rentalID).updateData({
        'chat': Firestore.instance.collection('messages').document(rentalID)
      });
      */

      setState(() {
        isUploading = false;
      });

      if (rentalID != null) {
        Navigator.pushNamed(
          context,
          RentalDetail.routeName,
          arguments: RentalDetailArgs(
            rentalID,
          ),
        );
      }
    }
  }

  Future<bool> sendItem() async {
    //if (widget.userEdit.displayName == userEditCopy.displayName) return true;

    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
        theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

    message = 'Hello ${creatorDS['displayName']}, '
        'I am requesting your ${itemDS['name']}. '
        'I would like to rent this item from '
        '${startDateTime} to ${endDateTime}';

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Preview message'),
              content: Text(
                message,
                style: dialogTextStyle,
              ),
              actions: <Widget>[
                FlatButton(
                  child: const Text('Go back'),
                  onPressed: () {
                    Navigator.of(context).pop(
                        false); // Pops the confirmation dialog but not the page.
                  },
                ),
                FlatButton(
                  child: const Text('Send'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    navToItemRental();
                    // Pops the confirmation dialog but not the page.
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> onWillPop() async {
    //if (widget.userEdit.displayName == userEditCopy.displayName) return true;

    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
        theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text(
                'Discard changes?',
                style: dialogTextStyle,
              ),
              actions: <Widget>[
                FlatButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(
                        false); // Pops the confirmation dialog but not the page.
                  },
                ),
                FlatButton(
                  child: const Text('Discard'),
                  onPressed: () {
                    Navigator.of(context).pop(
                        true); // Returning true to _onWillPop will pop again.
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class DateTimeItem extends StatelessWidget {
  DateTimeItem({Key key, DateTime dateTime, @required this.onChanged})
      : assert(onChanged != null),
        date = DateTime(dateTime.year, dateTime.month, dateTime.day),
        time = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
        super(key: key);

  final DateTime date;
  final TimeOfDay time;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DefaultTextStyle(
      style: theme.textTheme.subhead,
      child: Column(
        children: <Widget>[
          Container(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: theme.dividerColor))),
              child: InkWell(
                onTap: () {
                  showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: date.subtract(const Duration(days: 30)),
                    lastDate: date.add(const Duration(days: 30)),
                  ).then<void>((DateTime value) {
                    if (value != null)
                      onChanged(DateTime(value.year, value.month, value.day,
                          time.hour, time.minute));
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(DateFormat('EEE, MMM d yyyy').format(date)),
                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
          Container(
            //margin: const EdgeInsets.only(left: 8.0),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor))),
            child: InkWell(
              onTap: () {
                showTimePicker(
                  context: context,
                  initialTime: time,
                ).then<void>((TimeOfDay value) {
                  if (value != null)
                    onChanged(DateTime(date.year, date.month, date.day,
                        value.hour, value.minute));
                });
              },
              child: Row(
                children: <Widget>[
                  Text('${time.format(context)}'),
                  const Icon(Icons.arrow_drop_down, color: Colors.black54),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
