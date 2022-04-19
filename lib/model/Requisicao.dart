import 'package:cloud_firestore/cloud_firestore.dart';
import 'Destino.dart';
import 'Usuario.dart';

class Requisicao {

  late String _id;
  late String _status;
  late Usuario _passageiro;
  late Usuario _motorista;
  late Destino _destino;

  Requisicao(){

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentReference ref = db.collection("requisicoes").doc();
    this.id = ref.id;

  }

  Map<String, dynamic> toMap() {

    Map<String, dynamic> dadosPassageiro = {
      "nome" : this.passageiro.nome,
      "email" : this.passageiro.email,
      "tipoUsuario" : this.passageiro.tipoUsuario,
      "idUsuario" : this.passageiro.idUsuario,
      "latitude" : this.passageiro.latitude,
      "longitude" : this.passageiro.longitude,
    };

    Map<String, dynamic> dadosDestino = {
      "rua" : this.destino.rua,
      "numero" : this.destino.numero,
      "bairro" : this.destino.bairro,
      "cep" : this.destino.cep,
      "latitude" : this.destino.latitude,
      "longitude" : this.destino.longitude,
    };

    Map<String, dynamic> dadosRequisicao = {
      "id" : this.id,
      "status" : this.status,
      "passageiro" : dadosPassageiro,
      "motorista" : null,
      "destino" : dadosDestino,
    };

    return dadosRequisicao;

  }

  Destino get destino => _destino;

  set destino(Destino value) {
    _destino = value;
  }

  Usuario get motorista => _motorista;

  set motorista(Usuario value) {
    _motorista = value;
  }

  Usuario get passageiro => _passageiro;

  set passageiro(Usuario value) {
    _passageiro = value;
  }

  String get status => _status;

  set status(String value) {
    _status = value;
  }

  String get id => _id;

  set id(String value) {
    _id = value;
  }
}