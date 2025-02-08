use dotenv::dotenv;
use ethers::{
    abi::Abi,
    prelude::*,
    providers::{Provider, Ws},
    signers::{LocalWallet, Signer},
};
use futures_util::StreamExt;
use serde_json::Value;
use std::{env, sync::Arc};
use tracing::{error, info};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();

    let rpc_url = env::var("RPC_URL")?;
    let ws_provider = Provider::<Ws>::connect(rpc_url).await?;
    let provider = Arc::new(ws_provider);

    let private_key = env::var("PRIVATE_KEY")?;
    let wallet: LocalWallet = private_key.parse()?;
    let chain_id: u64 = env::var("CHAIN_ID")?.parse()?;
    let wallet = wallet.with_chain_id(chain_id);

    let client = SignerMiddleware::new(provider, wallet);
    let client = Arc::new(client);

    let contract_address: Address = env::var("CONTRACT_ADDRESS")?.parse()?;

    let abi_json: Value = serde_json::from_str(include_str!("../abi/InteropToken.json"))?;
    let abi_array = abi_json
        .get("abi")
        .ok_or_else(|| eyre::eyre!("ABI key missing"))?;
    let abi: Abi = serde_json::from_value(abi_array.clone())?;

    let contract = Contract::new(contract_address, abi, client);

    info!("Listening for Fill events...");

    let binding = contract.event::<FillEvent>();
    let mut event_stream = binding.subscribe().await?;

    while let Some(event) = event_stream.next().await {
        match event {
            Ok(FillEvent { order_id }) => {
                info!("Fill Event detected for Order ID {:?}", order_id);
                // if let Err(e) = confirm_order(order_id, &contract).await {
                //     error!("Failed to confirm order {:?}: {:?}", order_id, e);
                // }

                let calldata = contract.method::<_, H256>("confirm", order_id)?;
                let tx = calldata.send().await?;

                let receipt = tx.await?;

                if let Some(receipt) = receipt {
                    info!(
                        "Confirmed order {:?} with transaction {:?}",
                        order_id, receipt.transaction_hash
                    );
                } else {
                    error!(
                        "Transaction for order {:?} did not return a receipt",
                        order_id
                    );
                }
            }
            Err(e) => error!("Error receiving event: {:?}", e),
        }
    }

    Ok(())
}

#[derive(Debug, Clone, EthEvent)]
#[ethevent(name = "Fill", abi = "Fill(bytes32)")]
struct FillEvent {
    #[ethevent(indexed)]
    order_id: H256,
}

// async fn confirm_order(
//     order_id: H256,
//     contract: &Contract<Arc<SignerMiddleware<Provider<Ws>, LocalWallet>>>,
// ) -> eyre::Result<()> {
//     let calldata = contract.method::<_, H256>("confirm", order_id)?;
//     let tx = calldata.send().await?;

//     let receipt = tx.await?;

//     if let Some(receipt) = receipt {
//         info!(
//             "Confirmed order {:?} with transaction {:?}",
//             order_id, receipt.transaction_hash
//         );
//     } else {
//         error!(
//             "Transaction for order {:?} did not return a receipt",
//             order_id
//         );
//     }

//     Ok(())
// }
