use ecu_engine_messages::SpeedMessage;
use futures_util::SinkExt;
use tokio::net::lookup_host;
use tokio::signal::unix::{SignalKind, signal};
use tokio::time::{Duration, sleep};
use tokio_serde::Framed;
use tokio_serde::formats::*;
use tokio_util::codec::{Framed as UtilFramed, LengthDelimitedCodec};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = lookup_host("ecu_dashboard:8080")
        .await?
        .next()
        .ok_or("Failed to resolve ecu_dashboard")?;
    let mut speed_value: f64 = 0.0;

    println!("ECU Engine started. Attempting to send speed to {}", addr);

    let mut sigterm = signal(SignalKind::terminate()).unwrap();

    // Establish the connection before the loop
    let mut stream = tokio::net::TcpStream::connect(&addr).await?;

    // Create a LengthDelimitedCodec
    let length_delimited = UtilFramed::new(stream, LengthDelimitedCodec::new());

    // Create a TokioSerde framed stream
    let mut framed: Framed<
        UtilFramed<tokio::net::TcpStream, LengthDelimitedCodec>,
        SpeedMessage,
        SpeedMessage,
        Json<SpeedMessage, SpeedMessage>,
    > = Framed::new(
        length_delimited,
        Json::<SpeedMessage, SpeedMessage>::default(),
    );

    loop {
        tokio::select! {
            _ = sigterm.recv() => {
                println!("SIGTERM received, shutting down.");
                break;
            }
            _ = sleep(Duration::from_secs(1)) => {
                let speed_msg = SpeedMessage { speed: speed_value };
                if let Err(e) = framed.send(speed_msg).await {
                    eprintln!("Failed to send data: {}", e);
                    // Attempt to re-establish connection if sending fails
                    match tokio::net::TcpStream::connect(&addr).await {
                        Ok(new_stream) => {
                            stream = new_stream;
                            let length_delimited = UtilFramed::new(stream, LengthDelimitedCodec::new());
                            framed = Framed::new(length_delimited, Json::<SpeedMessage, SpeedMessage>::default());
                            println!("Re-established connection to {}", addr);
                        }
                        Err(connect_err) => {
                            eprintln!("Failed to re-establish connection to {}: {}", addr, connect_err);
                            // Optionally, break or continue depending on desired retry logic
                        }
                    }
                } else {
                    speed_value += 1.0;
                }
            }
        }
    }

    Ok(())
}
