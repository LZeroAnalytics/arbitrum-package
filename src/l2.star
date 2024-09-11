def launch_l2(
        plan,
        l2_services_suffix,
        l2_args,
        l1_config,
        l1_priv_key,
        l1_bootnode_context,
):
    plan.print("Launching L2 with params: {}, {}, {}, {}, {}".format(l2_services_suffix, l2_args, l1_config, l1_priv_key, l1_bootnode_context))