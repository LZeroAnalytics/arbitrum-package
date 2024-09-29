ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")
contract_deployer = import_module("./src/contracts/contract_deployer.star")
static_files = import_module(
    "github.com/ethpandaops/ethereum-package/src/static_files/static_files.star"
)
l2_launcher = import_module("./src/l2.star")
wait_for_sync = import_module("./src/wait/wait_for_sync.star")
input_parser = import_module("./src/package_io/input_parser.star")
sequencer_launcher = import_module("./src/sequencer/sequencer_launcher.star")


def run(plan, args):
    plan.print("Parsing the L1 input args")
    # If no args are provided, use the default values with minimal preset
    ethereum_args = args.get(
        "ethereum_package", {"network_params": {"preset": "minimal"}}
    )
    arbitrum_args = args.get("arbitrum_package", {})
    arbitrum_args_with_right_defaults = input_parser.input_parser(plan, arbitrum_args)
    # Deploy the L1
    plan.print("Deploying a local L1")
    l1 = ethereum_package.run(plan, ethereum_args)
    plan.print(l1)
    # Get L1 info
    all_l1_participants = l1.all_participants
    l1_network_params = l1.network_params
    l1_network_id = l1.network_id
    l1_priv_key = l1.pre_funded_accounts[
        12
    ].private_key  # reserved for L2 contract deployers
    l1_address = l1.pre_funded_accounts[
        12
    ].address
    l1_config_env_vars = get_l1_config(
        all_l1_participants, l1_network_params, l1_network_id
    )

    plan.print(all_l1_participants)

    # Wait for syncing to be done
    plan.wait(
        service_name = all_l1_participants[0].el_context.el_metrics_info[0]["name"],
        recipe = PostHttpRequestRecipe(
            port_id="rpc",
            endpoint="",
            body='{"jsonrpc": "2.0", "method": "eth_syncing", "params": [], "id": 1}',
            headers={
                "Content-Type": "application/json"
            },
            extract = {
                "status": ".result"
            }
        ),
        field = "extract.status",
        assertion = "==",
        target_value = False,
        interval = "1s",
        timeout = "5m",
        description = "Waiting for node to sync"
    )

    if l1_network_params.network != "kurtosis":
        wait_for_sync.wait_for_sync(plan, l1_config_env_vars)

    l2_contract_deployer_image = (
        arbitrum_args_with_right_defaults.contract_deployer_params.image
    )

    l2_config = arbitrum_args_with_right_defaults.network_params

    sequencer_launcher.start_service(plan, "sequencer", "offchainlabs/nitro-node:v3.0.1-cf4b74e-dev", all_l1_participants[0].el_context.rpc_http_url)
    # Deploy Create2 Factory contract (only need to do this once for multiple l2s)
    deployed_chain_info = contract_deployer.deploy_factory_contract(
        plan, l1_priv_key, l1_address, l1_config_env_vars, l2_config, l2_contract_deployer_image
    )
    sequencer_launcher.launch(plan, "sequencer", deployed_chain_info)


def get_l1_config(all_l1_participants, l1_network_params, l1_network_id):
    env_vars = {}
    env_vars["L1_RPC_KIND"] = "standard"
    env_vars["WEB3_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["L1_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["CL_RPC_URL"] = str(all_l1_participants[0].cl_context.beacon_http_url)
    env_vars["L1_WS_URL"] = str(all_l1_participants[0].el_context.ws_url)
    env_vars["L1_CHAIN_ID"] = str(l1_network_id)
    env_vars["L1_BLOCK_TIME"] = str(l1_network_params.seconds_per_slot)
    env_vars["DEPLOYMENT_OUTFILE"] = (
            "/workspace/optimism/packages/contracts-bedrock/deployments/"
            + str(l1_network_id)
            + "/kurtosis.json"
    )
    env_vars["STATE_DUMP_PATH"] = (
            "/workspace/optimism/packages/contracts-bedrock/deployments/"
            + str(l1_network_id)
            + "/state-dump.json"
    )

    return env_vars