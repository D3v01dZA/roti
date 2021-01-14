use actix_web::{get, post, web, App, HttpServer, Responder};
use serde::{Deserialize, Serialize};
use std::sync::{RwLock, Arc};

#[get("/peer")]
async fn peers(context: web::Data<Context>) -> impl Responder {
    return web::Json(context.peers.read().unwrap().to_vec());
}

#[post("/peer")]
async fn add_peer(context: web::Data<Context>, peer: web::Json<Peer>) -> impl Responder {
    let mut locked_peers = context.peers.write().unwrap();
    locked_peers.push(peer.clone());
    return peer;
}

#[derive(Serialize, Deserialize, Clone)]
struct Peer {
    address: String
}

#[derive(Clone)]
struct Context {
    peers: Arc<RwLock<Vec<Peer>>>
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let context = Context { peers: Arc::new(RwLock::new(vec![])) };

    HttpServer::new(move || {
        App::new()
            .data(context.clone())
            .service(peers)
            .service(add_peer)
    })
        .bind("127.0.0.1:8080")?
        .run()
        .await
}