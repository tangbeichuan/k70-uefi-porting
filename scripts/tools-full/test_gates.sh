set +e
cd /root/k70/uefi/Platforms/Xiaomi/vermeerPkg
cp vermeer.dsc /tmp/t.dsc; cp vermeer.fdf /tmp/t.fdf
python3 /mnt/d/本地项目-01/_k70port_extract/wsl/gates.py keyprobe vermeer.dsc vermeer.fdf
echo "fdf SimpleFb count: $(grep -c 'SimpleFbDxe' vermeer.fdf)"
echo "dsc SimpleFb count: $(grep -c 'SimpleFbDxe' vermeer.dsc)"
echo "--- fdf context ---"
grep -n -B3 -A3 "SimpleFbDxe" vermeer.fdf | head -20
cp /tmp/t.dsc vermeer.dsc; cp /tmp/t.fdf vermeer.fdf
echo "restored"