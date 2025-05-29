import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alerta Buenaventura',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.redAccent,
        scaffoldBackgroundColor: Color(0xFF121212),
        colorScheme: ColorScheme.dark(primary: Colors.redAccent),
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return MapScreen(); // Muestra mapa si está logueado
          } else {
            return LoginScreen(); // Muestra login si no
          }
        },
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Alerta Buenaventura",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await _signInWithGoogle();
              },
              icon: Icon(Icons.login),
              label: Text("Iniciar con Google"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  Position? currentPosition;

  final CollectionReference reports =
      FirebaseFirestore.instance.collection('reports');

  late LatLng initialLocation = LatLng(3.8642, -77.2708); // Buenaventura

  Set<Marker> markers = {};

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentPosition = position;
      initialLocation = LatLng(position.latitude, position.longitude);
    });
    mapController.animateCamera(CameraUpdate.newLatLng(initialLocation));
  }

  void _addReport(LatLng point) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
    String address = placemarks.isNotEmpty ? '${placemarks.first.name}, ${placemarks.first.locality}' : 'Dirección desconocida';

    await reports.add({
      'type': 'altercado',
      'location': GeoPoint(point.latitude, point.longitude),
      'address': address,
      'userId': FirebaseAuth.instance.currentUser?.uid ?? 'anonimo',
      'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'Anónimo',
      'status': 'activo',
      'createdAt': DateTime.now(),
      'isUrgent': false,
    });

    _loadReports();
  }

  void _loadReports() {
    reports.where('status', isEqualTo: 'activo').snapshots().listen((snapshot) {
      setState(() {
        markers.clear();
        snapshot.docs.forEach((doc) {
          var data = doc.data() as Map<String, dynamic>;
          GeoPoint location = data['location'];
          markers.add(Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(location.latitude, location.longitude),
            infoWindow: InfoWindow(title: data['type'], snippet: data['address']),
          ));
        });
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Alerta Buenaventura")),
      body: GoogleMap(
        onMapCreated: (controller) => mapController = controller,
        initialCameraPosition: CameraPosition(target: initialLocation, zoom: 14),
        markers: markers,
        onTap: _addReport,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addReport(initialLocation),
        child: Icon(Icons.add_alert),
      ),
    );
  }
}
