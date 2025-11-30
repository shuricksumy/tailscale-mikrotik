/interface bridge
add name=dockers

/interface veth
add address=172.17.0.2/16 dhcp=no \
    gateway=172.17.0.1 gateway6="" name=veth1

/container
add check-certificate=no dns=1.1.1.1,8.8.8.8 envlists=tailscale \
    interface=veth1 layer-dir=/usb1-part1/lays mountlists=tailscale name=\
    tailscale remote-image=shuricksumy/tailscale-mikrotik:latest\
    start-on-boot=yes

/container config
set layer-dir=/usb1-part1/lays registry-url=https://ghcr.io tmpdir=\
    /usb1-part1/pull

/container envs
add key=ADVERTISE_ROUTES list=tailscale value=192.168.222.0/24
add key=AUTH_KEY list=tailscale value=\
    f8895cc531d735f711ea0c2sss6dd8a561a94ebe7bce
add key=CONTAINER_GATEWAY list=tailscale value=172.17.0.1
add key=LOGIN_SERVER list=tailscale value=https://headscale.xxx.me
add key=TAILSCALE_ARGS list=tailscale value=\
    "--accept-routes --advertise-exit-node --netfilter-mode=on"
add key=TS_FORCE_NOISE_443 list=tailscale value=false
add key=TS_USERSPACE list=tailscale value=false
add key=UPDATE_TAILSCALE list=tailscale value=Y
add key=PASSWORD list=tailscale_ value=intuitsiya!

/container mounts
add dst=/var/lib/tailscale list=tailscale src=\
    /usb1-part1/containers/tailscale

/interface bridge port
add bridge=dockers interface=veth1

/ip address
add address=172.17.0.1/16 interface=dockers network=172.17.0.0

/ip route
add disabled=no distance=1 dst-address=100.64.0.0/10 gateway=172.17.0.2 \
    routing-table=main
