import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubber/model/Usuario.dart';

class UsuarioFirebase {

  static Future getUsuarioAtual() async {

    User? user = FirebaseAuth.instance.currentUser;
    return await user;

  }

  static Future getDadosUsuarioLogado() async {

    //FirebaseAuth firebaseAuth = await getUsuarioAtual();
    User? user = FirebaseAuth.instance.currentUser;
    //String idUsuario = firebaseAuth.currentUser!.uid;
    String idUsuario = user!.uid;

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot snapshot = await db.collection("usuarios")
        .doc( idUsuario )
        .get();

    Map<String, dynamic> dados = snapshot.data() as Map<String, dynamic>;
    String tipoUsuario = dados["tipoUsuario"];
    String email = dados["email"];
    String nome = dados["nome"];

    Usuario usuario = Usuario();
    usuario.idUsuario = idUsuario;
    usuario.tipoUsuario = tipoUsuario;
    usuario.email = email;
    usuario.nome = nome;

    return usuario;

  }

  static atualizarDadosLocalizacao(String idRequisicao, double lat, double lon ) async {

    FirebaseFirestore db = FirebaseFirestore.instance;

    Usuario motorista = await getDadosUsuarioLogado();


  }

}