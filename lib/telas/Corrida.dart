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
  late Position _localMotorista;

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function()? _funcaoBotao;

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

      setState(() {

        _exibirMarcadorPassageiro( position );

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 19
        );
        _movimentarCamera(_posicaoCamera );
        _localMotorista = position;
      });

    });

  }

  _recuperaUltimaLocalizacao() async {

    Position? position = await Geolocator
        .getLastKnownPosition();

    setState(() {
      if( position != null ){

        _exibirMarcadorPassageiro( position );

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 19
        );

        _movimentarCamera( _posicaoCamera );
        _localMotorista = position;
      }
    });

  }

  _movimentarCamera( CameraPosition cameraPosition ) async {

    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
            cameraPosition
        )
    );

  }

  _exibirMarcadorPassageiro(Position local) async {

    double pixeRatio =  MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        "imagens/motorista.png"
    ).then((BitmapDescriptor icone) {

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: "Meu local"
          ),
          icon: icone
      );

      setState(() {
        _marcadores.add( marcadorPassageiro );
      });

    });


  }

  _recuperarReuisicao() async {

    String? idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot = await db.collection("requisicoes")
    .doc( idRequisicao ).get();

    _dadosRequisicao = documentSnapshot.data() as Map<String, dynamic>?;
    _adicionarListenerRequisicao();

  }

  _adicionarListenerRequisicao() async {

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao!["id"];
    await db.collection("requisicoes")
    .doc( idRequisicao ).snapshots().listen((snapshot){

      if( snapshot.data() != null ){

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
  }
  _statusACAminho(){

    _alterarBotaoPrincipal(
        "A caminho do passageiro",
        Colors.grey,
            () {
          _Segue();
        });

  }

  _Segue(){}

  _aceitarCorrida() async {

    //Recuperar dados do motorista
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

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

    _recuperaUltimaLocalizacao();
    _adcionarListenerLocalizacao();

    //Recuperar requisicao e
    // adicionar listener para mudança de status
    _recuperarReuisicao();



  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida"),

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
