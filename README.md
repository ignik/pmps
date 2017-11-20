# pmps
perl multicast sip phone provisioning server

# installation:
apt install libio-socket-multicast-perl libio-interface-perl # IO::Socket::Multicast IO::Interface::Simple module

# first start:
./pmps.pl -v -v -i interface # reboot phone and see led lights

# any questions:
wireshark &
