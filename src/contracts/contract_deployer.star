def deploy_factory_contract(
        plan,
        priv_key,
        l1_config_env_vars,
        image,
):
    plan.print("Deploying contract {}, {}, {}".format(priv_key, l1_config_env_vars, image))