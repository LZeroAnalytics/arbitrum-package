def start_service(
        plan,
        service_name,
        image,
        l1_url,
        private_key,
        address
):

    sequencer_config = render_sequencer_config(plan, l1_url, private_key, address)

    plan.add_service(
        name=service_name,
        config = ServiceConfig(
            image = image,
            ports = {
                "rpc": PortSpec(number=8547, transport_protocol="TCP", wait=None),
                "ws": PortSpec(number=8548, transport_protocol="TCP", wait=None),
                "feed": PortSpec(number=9642, transport_protocol="TCP", wait=None)
            },
            cmd = [
                "tail",
                "-f",
                "/dev/null"
            ],
            entrypoint = [
                "tail",
                "-f",
                "/dev/null"
            ],
            files = {
                "/config": sequencer_config
            }
        )
    )

def launch(
        plan,
        service_name,
        deployed_chain_info,
        l1_url,
        private_key
):
    plan.exec(
        service_name=service_name,
        description="Adding deployed chain info",
        recipe = ExecRecipe(
            command=[
                "/bin/bash",
                "-c",
                'cat > /home/user/l2_chain_config.json <<EOF\n{}\nEOF'.format(deployed_chain_info)
            ]
        )
    )

    plan.exec(
        service_name=service_name,
        description="Creating poster account",
        recipe = ExecRecipe(
            command=[
                "/bin/bash",
                "-c",
                "nitro --chain.dev-wallet.only-create-key --chain.dev-wallet.account sequencer --chain.dev-wallet.password passphrase --chain.dev-wallet.pathname /home/user/l1keystore --chain.dev-wallet.private-key {0} --parent-chain.connection.url {1} --parent-chain.id 3151908 --chain.id 412346 --chain.info-files /home/user/l2_chain_config.json --execution.forwarding-target null --node.dangerous.disable-blob-reader".format(private_key, l1_url)
            ]
        ),
        acceptable_codes = [0, 1, 2]
    )

    plan.exec(
        service_name=service_name,
        description="Starting sequencer and batcher",
        recipe = ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                "nohup nitro --conf.file /config/sequencer_config.json --node.feed.output.enable --node.feed.output.port 9642 --http.api net,web3,eth,txpool,debug --node.seq-coordinator.my-url ws://0.0.0.0:8548 > /dev/null 2>&1 &"
            ]
        )
    )

def render_sequencer_config(
        plan,
        l1_url,
        private_key,
        address
):
    template_data = {
        "L1URL": l1_url,
        "PrivateKey": private_key,
        "Address": address
    }

    return plan.render_templates(
        config = {
            "sequencer_config.json": struct(
                template=read_file("templates/sequencer_config.json.tmpl"),
                data=template_data,
            )
        }
    )