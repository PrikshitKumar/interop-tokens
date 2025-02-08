use dotenv::dotenv;
use ethers::{
    abi::Abi,
    contract::EthEvent,
    prelude::*,
    providers::{Provider, Ws},
    signers::{LocalWallet, Signer},
};
use std::{env, sync::Arc};
use tracing::{error, info};

#[derive(Debug, Clone, EthEvent)]
struct OpenOrder {
    #[ethevent(indexed)]
    order_id: H256,
    #[ethevent(indexed)]
    user: Address,
    amount: U256,
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();

    let rpc_url = env::var("RPC_URL")?;
    let chain_id: u64 = env::var("CHAIN_ID")?.parse()?;  
    let ws_provider = Provider::<Ws>::connect(rpc_url).await?;
    let provider = Arc::new(ws_provider);

    let private_key = env::var("PRIVATE_KEY")?;
    let wallet: LocalWallet = private_key.parse()?;
    let wallet = wallet.with_chain_id(chain_id);
    let client = Arc::new(SignerMiddleware::new(provider.clone(), wallet.clone()));

    let contract_address: Address = env::var("CONTRACT_ADDRESS")?.parse()?;
    let abi: Abi = serde_json::from_str(include_str!("../abi/InteropToken.json"))?;
    let contract = Contract::new(contract_address, abi, client.clone());

    info!("Listening for OpenOrder events...");

    let event_stream = contract.event::<OpenOrder>().from_block(0u64);
    let mut stream = event_stream.stream().await?.take(10);

    while let Some(event) = stream.next().await {
        match event {
            Ok(OpenOrder {
                order_id,
                user,
                amount,
            }) => {
                info!(
                    "New Order Event: Order ID {:?}, User: {:?}, Amount: {:?}",
                    order_id, user, amount
                );

                if validate_order(order_id, user, amount).await {
                    if let Err(e) = relay_transaction(order_id, user, amount).await {
                        error!("Failed to relay order {:?}: {:?}", order_id, e);
                    }
                } else {
                    error!("Invalid order: {:?}", order_id);
                }
            }
            Err(e) => error!("Error receiving event: {:?}", e),
        }
    }

    Ok(())
}

async fn validate_order(order_id: H256, user: Address, amount: U256) -> bool {
    // TODO: Implement order validation logic
    info!(
        "Validating order {:?} for user {:?} with amount {:?}",
        order_id, user, amount
    );
    true
}

async fn relay_transaction(order_id: H256, user: Address, amount: U256) -> eyre::Result<()> {
    // TODO: Implement relayer logic to send transaction to destination chain
    info!("Relaying transaction for order {:?}...", order_id);
    Ok(())
}
