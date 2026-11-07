/// Same Firebase project as the website (embedded/src/api/_firebase.js).
/// A Firebase web API key only identifies the project; access is enforced by
/// your Realtime Database rules, so keep those requiring `auth != null`.
const firebaseApiKey = 'AIzaSyC1bgIccBoMf2tjPSsP1PdI8Y5Wc88Tsd8';
const firebaseDbUrl = 'https://parcelbonia-default-rtdb.asia-southeast1.firebasedatabase.app';

const deviceId = 'PB-01';
const deviceRoot = 'devices/$deviceId';
