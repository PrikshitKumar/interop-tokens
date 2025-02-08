use ethers::{
    core::types::{Filter, H256},
    providers::{Middleware, Provider, StreamExt, Ws},
    utils::keccak256,
};
use std::{env, sync::Arc};
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    dotenv::dotenv().ok(); // Load environment variables from .env file

    let rpc_url = env::var("RPC_URL").expect("RPC_URL must be set in .env");
    let contract_address = env::var("CONTRACT_ADDRESS")
        .expect("CONTRACT_ADDRESS must be set in .env")
        .parse()?;

    // WebSocket Provider for event listening
    let ws_provider = Arc::new(Provider::<Ws>::connect(&rpc_url).await?);

    println!("🔗 Listening for contract events...");
    listen_for_events(ws_provider, contract_address).await?;

    Ok(())
}

async fn listen_for_events(
    ws_provider: Arc<Provider<Ws>>,
    contract_address: H256,
) -> eyre::Result<()> {
    let filter = Filter::new().address(contract_address);

    let mut stream = ws_provider.subscribe_logs(&filter).await?.fuse();

    while let Some(log) = stream.next().await {
        let log = log?;
        let event_signature: H256 = log.topics[0];

        if event_signature == H256::from(keccak256("Open(bytes32,bytes)")) {
            println!("🚀 Detected Open event!");
            process_transaction(log.data.0).await?;
        } else if event_signature == H256::from(keccak256("Fill(bytes32)")) {
            println!("✅ Order Filled!");
        } else if event_signature == H256::from(keccak256("Cancel(bytes32)")) {
            println!("❌ Order Cancelled!");
        } else {
            println!("⚠️ Unknown event detected!");
        }
    }

    Ok(())
}

async fn process_transaction(log_data: Vec<u8>) -> eyre::Result<()> {
    if log_data.len() < 32 {
        println!("⚠️ Invalid event data");
        return Ok(());
    }

    let order_id = H256::from_slice(&log_data[0..32]);
    println!("Processing Open Order: {:?}", order_id);

    sleep(Duration::from_secs(5)).await;
    println!("✅ Order {:?} processed!", order_id);

    Ok(())
}
