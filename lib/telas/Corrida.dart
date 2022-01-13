import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ubber/model/Usuario.dart';
import 'package:ubber/util/StatusRequisicao.dart';
import 'package:ubber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {

  String? idRequisicao;
  Corrida( this.idRequisicao );
  //const Corrida({Key? key}) : super(key: key);
  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {

  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera = CameraPosition(
      target: LatLng(-23.557425201980767, -46.65672565205034)
  );
  Set<Marker> _marcadores = {};
  Map<String, dynamic>? _dadosRequisicao;


  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function()? _funcaoBotao;
  late String _mensagemStatus;

  _alterarBotaoPrincipal(String texto, Color cor, Function()? funcao){

    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });

  }

  _onMapCreated( GoogleMapController controller ){
    _controller.complete( controller );
  }

  _adcionarListenerLocalizacao(){
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10
    );
    Geolocator.getPositionStream().listen((Position position) {

      if( position != null){

      }



    });

  }

  _recuperaUltimaLocalizacao() async {

    Position? position = await Geolocator
        .getLastKnownPosition();

    if( position != null ){

      //Atualizar localização em tempo real do motorista


    }


  }

  _movimentarCamera( CameraPosition cameraPosition ) async {

    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
            cameraPosition
        )
    );

  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {

    double pixeRatio =  MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        icone
    ).then((BitmapDescriptor bitmapDescriptor) {

      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: infoWindow
          ),
          icon: bitmapDescriptor
      );

      setState(() {
        _marcadores.add( marcador );
      });

    });


  }

  _recuperarReuisicao() async {

    String? idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot = await db.collection("requisicoes")
    .doc( idRequisicao ).get();



  }

  _adicionarListenerRequisicao() async {

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao!["id"];
    await db.collection("requisicoes")
    .doc( idRequisicao ).snapshots().listen((snapshot){

      if( snapshot.data() != null ){

        _dadosRequisicao = snapshot.data() as Map<String, dynamic>?;


        Map<String, dynamic>? dados = snapshot.data();
        String status = dados!["status"];

        switch( status ){
          case StatusRequisicao.AGUARDANDO :
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :
            _statusACAminho();

            break;
          case StatusRequisicao.VIAGEM :

            break;
          case StatusRequisicao.FINALIZADA :

            break;

        }

      }

    });
    

  }

  _statusAguardando(){

    _alterarBotaoPrincipal(
        "Aceitar corrida",
        Color(0xff1ebbd8),
        () {
        _aceitarCorrida();
    });

    double motoristaLat = _dadosRequisicao!["motorista"]["latitude"];
    double motoristaLon = _dadosRequisicao!["motorista"]["longitude"];

    Position position = Position(
      latitude: motoristaLat, longitude:motoristaLon, speedAccuracy: 10, speed: 0.0, heading: 0.0, altitude: 0.0, timestamp: null, accuracy: 0.0
    );
    _exibirMarcador(
        position,
        "imagens/motorista.png",
      "Motorista"
    );

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),zoom: 19);

    _movimentarCamera( cameraPosition );
  }
  _statusACAminho(){

    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
        "Iniciar corrida",
        Color(0xff1ebbd8),
            () {
          _iniciarCorrida();
            }
    );

    double latitudePassageiro = _dadosRequisicao!["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao!["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao!["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao!["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(
        LatLng(latitudeMotorista, longitudeMotorista),
        LatLng(latitudePassageiro, longitudePassageiro)
    );

    var nLat, nLon, sLat, sLon;

    if( latitudeMotorista <= latitudePassageiro){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else {
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if( longitudeMotorista <= longitudePassageiro){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    }else {
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBounds(
        LatLngBounds(
            northeast: LatLng(nLat, nLon), //nordeste
            southwest: LatLng(sLat, sLon) //sudoeste
        )
    );

  }

  _iniciarCorrida(){

  }

  _movimentarCameraBounds( LatLngBounds latLngBounds ) async {

    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
        CameraUpdate.newLatLngBounds(
          latLngBounds,
          100
       )
    );

  }

  _exibirDoisMarcadores(LatLng latlngMotorista, LatLng latlngPassageiro){

    double pixeRatio =  MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcador1 = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latlngMotorista.latitude, latlngMotorista.longitude),
          infoWindow: InfoWindow(title: "Local motorista"),
          icon: icone);
      _listaMarcadores.add( marcador1 );
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcador2 = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latlngPassageiro.latitude, latlngPassageiro.longitude),
          infoWindow: InfoWindow(title: "Local passageiro"),
          icon: icone);
      _listaMarcadores.add( marcador2 );
    });

    setState(() {
      _marcadores = _listaMarcadores;
      });

  }


  _aceitarCorrida() async {

    //Recuperar dados do motorista
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _dadosRequisicao!["motorista"]["latitude"];
    motorista.longitude = _dadosRequisicao!["motorista"]["longitude"];

    FirebaseFirestore db = FirebaseFirestore.instance;
    String? idRequisicao = _dadosRequisicao!["id"];

    db.collection("requisicoes")
    .doc( idRequisicao ).update({
      "motorista" : motorista.toMap(),
      "status" : StatusRequisicao.A_CAMINHO,
    }).then((_){

      //atualiza requisicao ativa
      String idPassageiro = _dadosRequisicao!["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa")
      .doc( idPassageiro ).update({
        "motorista" : motorista.toMap(),
        "status" : StatusRequisicao.A_CAMINHO,
      });

      //Salva requisicao ativa para motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista")
          .doc( idMotorista )
          .set({
        "id_requisicao" : idRequisicao,
        "id_usuario" : idMotorista,
        "status" : StatusRequisicao.A_CAMINHO,
      });

      });


  }

  @override
  void initState() {
    super.initState();

    // adicionar listener para mudança na requisicao
    _adicionarListenerRequisicao();

    //_recuperaUltimaLocalizacao();
    _adcionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - " + _mensagemStatus ),

      ),
      body: Container(
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: RaisedButton(
                    child: Text(
                      _textoBotao,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: _corBotao,
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: _funcaoBotao
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
