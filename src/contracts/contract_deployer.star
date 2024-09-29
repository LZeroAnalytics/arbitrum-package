def deploy_factory_contract(
        plan,
        owner_priv_key,
        owner_address,
        l1_config_env_vars,
        l2_config,
        image,
):

    wasm_root = plan.run_sh(
        name="wasm-root-query",
        description="Retrieving wasm room from the node",
        image="offchainlabs/nitro-node:v3.1.2-309340a",
        run="cat /home/user/target/machines/latest/module-root.txt | tr -d '\n'",
        wait="300s",
    )

    l2_config = render_l2_config(plan, l2_config, owner_address)

    plan.run_sh(
        name="l2-checker",
        description="Checking l2 config",
        image=image,
        run="cat /config/l2_chain_config.json",
        files= {
            "/config": l2_config
        }
    )


    env_vars = {
        "PARENT_CHAIN_RPC": l1_config_env_vars["L1_RPC_URL"],
        "DEPLOYER_PRIVKEY": str(owner_priv_key),
        "PARENT_CHAIN_ID": l1_config_env_vars["L1_CHAIN_ID"],
        "CHILD_CHAIN_NAME": "arb-dev-test",
        "MAX_DATA_SIZE": "117964",
        "OWNER_ADDRESS": owner_address,
        "SEQUENCER_ADDRESS": owner_address,
        "WASM_MODULE_ROOT": wasm_root.output,
        "AUTHORIZE_VALIDATORS": "10",
        "CHILD_CHAIN_CONFIG_PATH": "/config/l2_chain_config.json",
        "CHAIN_DEPLOYMENT_INFO": "/config/deployment.json",
        "CHILD_CHAIN_INFO": "/config/deployed_chain_info.json",
    }

    plan.run_sh(
        name="deploy-l2-chain",
        description="Deploying the L2 chain using rollupcreator",
        image=image,
        env_vars=env_vars,
        run="cd /workspace && yarn run create-rollup-testnode",
        files={
            "/config": l2_config
        },
        wait="300s",  # Wait for 5 minutes, as this may take some time
    )

    plan.print("Deployed contract with variables: {}".format(env_vars))


def render_l2_config(plan, l2_config, owner_address):
    # Define the data structure using l2_config and arbitrum_config as input

    config_data = {
        "chainId": l2_config.chainId,
        "homesteadBlock": l2_config.homesteadBlock,
        "daoForkSupport": l2_config.daoForkSupport,
        "eip150Block": l2_config.eip150Block,
        "eip150Hash": l2_config.eip150Hash,
        "eip155Block": l2_config.eip155Block,
        "eip158Block": l2_config.eip158Block,
        "byzantiumBlock": l2_config.byzantiumBlock,
        "constantinopleBlock": l2_config.constantinopleBlock,
        "petersburgBlock": l2_config.petersburgBlock,
        "istanbulBlock": l2_config.istanbulBlock,
        "muirGlacierBlock": l2_config.muirGlacierBlock,
        "berlinBlock": l2_config.berlinBlock,
        "londonBlock": l2_config.londonBlock,
        "cliquePeriod": l2_config.cliquePeriod,
        "cliqueEpoch": l2_config.cliqueEpoch,
        "EnableArbOS": l2_config.EnableArbOS,
        "AllowDebugPrecompiles": l2_config.AllowDebugPrecompiles,
        "DataAvailabilityCommittee": l2_config.DataAvailabilityCommittee,
        "InitialArbOSVersion": l2_config.InitialArbOSVersion,
        "InitialChainOwner": owner_address,
        "GenesisBlockNum": l2_config.GenesisBlockNum
    }

    return plan.render_templates(
        config={
            "l2_chain_config.json": struct(
                template=read_file("templates/l2_config.json.tmpl"),
                data=config_data,
            )
        },
        name="chain-config"
    )