import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geocoding/geocoding.dart';

import 'package:ubber/model/Destino.dart';
import 'package:ubber/model/Requisicao.dart';
import 'package:ubber/model/Usuario.dart';
import 'package:ubber/util/StatusRequisicao.dart';
import 'package:ubber/util/UsuarioFirebase.dart';

import '../model/Marcador.dart';


class PainelPassageiro extends StatefulWidget {
  const PainelPassageiro({Key? key}) : super(key: key);
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro>  {

  late LatLng _center ;
  late Position currentLocation;

  TextEditingController _controllerDestino = TextEditingController(text: "Rua das Primaveras, 270");
  List<String> itensMenu = ["Configurações", "Deslogar"];
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =  CameraPosition(target: LatLng(-23.557425201980767, -46.65672565205034),zoom: 16);
  Set<Marker> _marcadores = {};
  late String _idRequisicao;
  late Position _localPassageiro;
  late Map<String, dynamic> _dadosRequisicao;
  late StreamSubscription<DocumentSnapshot> _streamSubscriptionRequisicoes;

  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "Chamar uber";
  Color _corBotao = Color(0xff1ebbd8);
  Function()? _funcaoBotao;

  Future<Position> locateUser() async {
    return Geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  getUserLocation() async {
    currentLocation = await locateUser();
    setState(() {
      _center = LatLng(currentLocation.latitude, currentLocation.longitude);
      _posicaoCamera =  CameraPosition(target: LatLng(currentLocation.latitude, currentLocation.longitude),zoom: 16);

      _posicaoCamera = CameraPosition(
          target: LatLng(currentLocation.latitude, currentLocation.longitude), zoom: 19);
      _localPassageiro = currentLocation;
      _movimentarCamera(_posicaoCamera);


    });
    print('center $_center');
  }

  _deslogarUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");

  }

  _escolhaMenuItem( String escolha ){
    switch( escolha ){
      case "Deslogar" :
        _deslogarUsuario();
        break;
      case "Configurações" :
        _deslogarUsuario();
        break;
    }

  }

  _onMapCreated( GoogleMapController controller ){
    _controller.complete( controller );
  }


  _adcionarListenerLocalizacao(){
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);
// ver isso
   Geolocator.getPositionStream().listen((Position position) {

      if( _idRequisicao != null && _idRequisicao.isNotEmpty ){

        //Atualiza local do passageiro
        UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao,
            position.latitude,
            position.longitude
        );

      }else{
        setState(() {
          _localPassageiro = position;
        });
        _statusUberNaoChamado();
      }

    });

  }


  _recuperaUltimaLocalizacaoConhecida() async {
    Position? position = await Geolocator
        .getLastKnownPosition();

    setState(() {
      if (position != null) {
        _exibirMarcadorPassageiro(position);

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        _localPassageiro = position;
        _movimentarCamera(_posicaoCamera);
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
        "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add( marcadorPassageiro );
      });
    });
  }

  _chamarUber() async {

    String enderecoDestino = _controllerDestino.text;


    if( enderecoDestino.isNotEmpty ){

      var locations  = await locationFromAddress(enderecoDestino, localeIdentifier: "pt_BR");
      //List<Placemark> listaEnderecos = await placemarkFromCoordinates(locations[0].longitude,locations[0].latitude);
      var listaEnderecos = await placemarkFromCoordinates(locations[0].latitude,locations[0].longitude, localeIdentifier: "pt_BR");

      if( listaEnderecos != null && listaEnderecos.length > 0){

        final Placemark endereco = listaEnderecos.first;
        Destino destino = Destino();
        destino.cidade = endereco.subAdministrativeArea!;
        destino.cep = endereco.postalCode!;
        destino.bairro = endereco.subLocality!;
        destino.rua = endereco.thoroughfare!;
        destino.numero = endereco.subThoroughfare!;

        destino.latitude = locations[0].latitude;
        destino.longitude = locations[0].longitude;

        String  enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: " + destino.cidade;
        enderecoConfirmacao += "\n Rua: " + destino.rua + "," + destino.numero ;
        enderecoConfirmacao += "\n Bairro: " + destino.bairro ;
        enderecoConfirmacao += "\n Cep: " + destino.cep ;

        showDialog(
            context: context,
            builder: (context){
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  FlatButton(
                    child: Text("Cancelar", style: TextStyle(color: Colors.red),),
                    onPressed: () => Navigator.pop(context),
                  ),
                  FlatButton(
                    child: Text("Confirmar", style: TextStyle(color: Colors.green),),
                    onPressed: (){

                      //salvar requisicao
                      _salvarRequisicao( destino );

                      Navigator.pop(context);

                    },
                  )
                ],
              );
          });
      }
    }
  }

  _salvarRequisicao( Destino destino ) async {
    /*
    + requisicao
      + ID_REQUISICAO
      + destino
      + passageiro
      + motorista
      + status

    * */
    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;
print("aqui q ta pegando");
    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro =  passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    //salvar requisição
    db
        .collection("requisicoes")
        .doc( requisicao.id )
        .set( requisicao.toMap() );

    //Salvar requisição ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db
        .collection("requisicao_ativa")
        .doc( passageiro.idUsuario )
        .set( dadosRequisicaoAtiva );

    //chama método para alterar interface para o status aguardando
    //_statusAguardando();
    //Adicionar listener requisicao
    if( _streamSubscriptionRequisicoes == null ){
      _adicionarListenerRequisicao( requisicao.id );
    }

  }

  _alterarBotaoPrincipal(String texto, Color cor, Function()? funcao){

    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestino = true;

    _alterarBotaoPrincipal("Chamar uber", Color(0xff1ebbd8), () {
      _chamarUber();
    });

    if( _localPassageiro != null ) {
      Position position = Position(
          latitude: _localPassageiro.latitude,
          longitude: _localPassageiro.longitude,
          speed: 10,
          heading: 0.0,
          accuracy: 0.0,
          altitude: 0.0,
          speedAccuracy: 0.0,
          timestamp: null
      );
      _exibirMarcadorPassageiro(position);
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _movimentarCamera(cameraPosition);
    }

  }

  _statusAguardando(){
    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal("Cancelar",Colors.red, (){
      _cancelarUber();
    });

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];

    Position position = Position(
        latitude: passageiroLat,
        longitude: passageiroLon,
        speed: 10, heading: 0.0, accuracy: 0.0, altitude: 0.0, speedAccuracy: 0.0, timestamp: null
    );
    _exibirMarcadorPassageiro( position );
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera( cameraPosition );

  }

  _statusACaminho(){

    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal(
        "Motorista a caminho",
        Colors.grey,
            (){

        });

    double latitudeDestino = _dadosRequisicao!["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao!["passageiro"]["longitude"];

    double latitudeOrigem = _dadosRequisicao!["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao!["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista");

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/passageiro.png",
        "Local destino");

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);




  }

  _statusEmViagem(){

    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal(
        "Em viagem",
        Colors.grey,
        null
    );

    double latitudeDestino = _dadosRequisicao!["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao!["passageiro"]["longitude"];

    double latitudeOrigem = _dadosRequisicao!["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao!["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
      LatLng(latitudeOrigem, longitudeOrigem),
      "imagens/motorista.png",
      "Local motorista");

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/destino.png",
        "Local destino");

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);

  }

  _exibirCentralizarDoisMarcadores( Marcador marcadorOrigem, Marcador marcadorDestino){

    double latitudeOrigem = marcadorOrigem.local.latitude;
    double longitudeOrigem = marcadorOrigem.local.longitude;

    double latitudeDestino = marcadorDestino.local.latitude;
    double longitudeDestino = marcadorDestino.local.longitude;

    //Exibir dois marcadores
    _exibirDoisMarcadores(
       marcadorOrigem,
       marcadorDestino
    );

    var nLat, nLon, sLat, sLon;

    if( latitudeOrigem <= latitudeDestino){
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    }else {
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }

    if( longitudeOrigem <= longitudeDestino){
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    }else {
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }

    _movimentarCameraBounds(
        LatLngBounds(
            northeast: LatLng(nLat, nLon), //nordeste
            southwest: LatLng(sLat, sLon) //sudoeste
        )
    );

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

  _exibirDoisMarcadores( Marcador marcadorOrigem, Marcador marcadorDestino ){

    double pixeRatio =  MediaQuery.of(context).devicePixelRatio;

    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestino = marcadorDestino.local;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        marcadorOrigem.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mOrigem = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone);
      _listaMarcadores.add( mOrigem );
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        marcadorDestino.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mDestino = Marker(
          markerId: MarkerId(marcadorDestino.caminhoImagem),
          position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
          infoWindow: InfoWindow(title: marcadorDestino.titulo),
          icon: icone);
      _listaMarcadores.add( mDestino );
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });

  }

  _cancelarUber() async {

    var usuarioLogado = await FirebaseAuth.instance.currentUser;

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
    .doc( _idRequisicao ).update({
      "status" : StatusRequisicao.CANCELADA
    }).then((_) {

      db.collection("requisicao_ativa")
          .doc( usuarioLogado!.uid )
          .delete();
    });

  }

  _recuperarRequisicaoAtiva() async {

    FirebaseAuth auth = FirebaseAuth.instance;

    var usuarioLogado = await FirebaseAuth.instance.currentUser;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicao_ativa")
        .doc( usuarioLogado!.uid )
        .get();

    if( documentSnapshot.data() != null ){

      var dados = documentSnapshot.data() as Map<String, dynamic>?;
      _idRequisicao = dados!["id_requisicao"];
      _adicionarListenerRequisicao( _idRequisicao );

    }else {

      _statusUberNaoChamado();

    }

  }

  _adicionarListenerRequisicao(String idRequisicao) async {

    FirebaseFirestore db = FirebaseFirestore.instance;
    await db.collection("requisicoes")
        .doc( idRequisicao ).snapshots().listen((snapshot) {

      if( snapshot.data() != null){

        Map<String, dynamic>? dados = snapshot.data();
        _dadosRequisicao = dados!;
        String status = dados!["status"];
        _idRequisicao = dados!["id_requisicao"];

        switch( status ){
          case StatusRequisicao.AGUARDANDO :
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM :
            _statusEmViagem();
            break;
          case StatusRequisicao.FINALIZADA :

            break;

        }

      }

    });

  }

  @override
  void initState() {
    super.initState();

    getUserLocation();

    //adcionar listener para requisicao ativa
    _recuperarRequisicaoAtiva();

    //_recuperaUltimaLocalizacao();
    _adcionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context){
              return itensMenu.map((String item){
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          )
        ],
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
            Visibility(
              visible: _exibirCaixaEnderecoDestino,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white
                        ),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20, top: 5),
                                width: 10,
                                height: 10,
                                child: Icon(Icons.location_on, color: Colors.green,),
                              ),
                              hintText: "Meu local",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 15, top: 16)
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white
                        ),
                        child: TextField(
                          controller: _controllerDestino,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20, top: 5),
                                width: 10,
                                height: 10,
                                child: Icon(Icons.local_taxi, color: Colors.black,),
                              ),
                              hintText: "Digite o destino",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 15, top: 16)
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
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

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisicoes.cancel();
  }

}
