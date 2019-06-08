const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp(functions.config().firebase);

const firestore = admin.firestore();
const settings = { timestampInSnapshots: true };
firestore.settings(settings);

const storage = admin.storage();
const bucket = storage.bucket();

const stripe = require('stripe')(functions.config().stripe.token);

// add stripe source when new card added
exports.addStripeSource = functions.firestore.document('cards/{userId}/tokens/{tokenId}')
    .onWrite(async (tokenSnap, context) => {
        var customer;
        const data = tokenSnap.after.data();

        if (data === null) {
            return null
        }

        const token = data.tokenId;
        const snapshot = await firestore.collection('cards').doc(context.params.userId).get();
        const customerId = snapshot.data().custId;
        const customerEmail = snapshot.data().email;

        if (customerId === 'new') {
            customer = await stripe.customers.create({
                email: customerEmail,
                source: token
            });

            firestore.collection('cards').doc(context.params.userId).update({
                custId: customer.id
            });
        } else {
            customer = await stripe.customers.retrieve(customerId);
        }

        const customerSource = customer.sources.data[0];

        return firestore.collection('cards').doc(context.params.userId).collection('sources').
            doc(customerSource.card.fingerprint).set(customerSource, {
                merge: true
            });
    })

// create new user document when account created
exports.createUser = functions.auth.user().onCreate(event => {
    console.log('User id to be created: ', event.uid);

    const userID = event.uid;
    const email = event.email;
    const photoURL = event.photoURL || 'https://firebasestorage.googleapis.com/v0/b/shareapp-rrd.appspot.com/o/profile_pics%2Fnew_user.png?alt=media&token=60762aec-fa4f-42cd-9d4b-656bd92aeb6d';
    const name = event.displayName || 'new user';
    const creationDate = Date.now();

    firestore.collection('cards').doc(userID).set({
        custId: 'new',
        email: email,
    }).then(function () {
        console.log('Added card for user ', userID);
        return 'Added card for user $userID';
    }).catch(error => {
        console.error('Error when adding card for new user! ', error);
    });

    return firestore.collection('users').doc(userID).set({
        email: email,
        avatar: photoURL,
        name: name,
        lastActive: Date.now(),
        creationDate: creationDate,
    }).then(function () {
        console.log('Created user: ', userID);
        return 'Created user $userID';
    }).catch(error => {
        console.error('Error when creating user! ', error);
    });
});

// delete user account in firestore when account deleted
exports.deleteUser = functions.auth.user().onDelete(event => {
    console.log('User id to be deleted: ', event.uid);

    const userID = event.uid;

    firestore.collection('cards').doc(userID).delete().then(function () {
        console.log('Deleted card for user ', userID);
        return 'Deleted card for user $userID';
    }).catch(error => {
        console.error('Error when deleting card for user $userID', error);
    });

    const filePath = `profile_pics/${userID}`;
    const file = bucket.file(filePath);

    file.delete().then(() => {
        console.log(`Successfully deleted profile pic with user id: ${userID} at path ${filePath}`);
        return 'Delete photo profile pic success';
    }).catch(err => {
        console.error(`Failed to remove images, error: ${err}`);
    });

    return firestore.collection('users').doc(userID).delete().then(function () {
        console.log('Deleted user: ', userID);
        return 'Deleted user $userID';
    }).catch(error => {
        console.error('Error when delting user! $userID', error);
    });
});

// delete images from item in firebase storage when item document deleted
exports.deleteItemImages = functions.firestore.document('items/{itemId}')
    .onDelete(async (snap, context) => {
        const deletedValue = snap.data();
        const id = deletedValue.id;

        if (id === null) {
            return null;
        }

        console.log(`itemId to be deleted: ${id}`);

        bucket.deleteFiles({
            prefix: `items/${id}/`
        }, function (err) {
            if (!err) {
                console.log(`Successfully deleted images with item id: ${id}`);
            } else {
                console.error(`Failed to remove images, error: ${err}`);
            }
        });
    })

/*
exports.addItem = functions.https.onCall((data, context) => {
    const itemsCollection = firestore.collection('items');
    const snapshot = await itemsCollection.add({
        id: data['id'],
        status: data['status'],
        creator: data['creator'],
        name: data['name'],
        description: data['description'],
        type: data['type'],
        condition: data['condition'],
        price: data['price'],
        numImages: data['numImages'],
        location: data['location'],
        rental: data['rental'],
    });

    itemsCollection.doc(snapshot.documentID).update({
        id: customer.id
    });
});
*/