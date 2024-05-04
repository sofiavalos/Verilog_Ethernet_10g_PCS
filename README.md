<h1 align="center"> Ethernet 10GBASE PCS </h1>

<p align="center">
   <img src="https://img.shields.io/badge/STATUS-EN%20DESAROLLO-green">
</p>

## Repositorio
La base del repositorio son los módulos proporcionados por [Alex Forenchich](https://github.com/alexforencich/verilog-ethernet) en su propio repositorio.

## Documentación
El bloque PCS se encuentra estructurado de la siguiente manera:

```
eth_phy_10g
  └── eth_phy_10g_rx - eth_phy_10g_rx_inst
      ├── eth_phy_10g_rx_if - eth_phy_10g_rx_if_inst
      │   ├── lfsr - descrambler_inst
      │   ├── lfsr - prbs31_check_inst
      │   ├── eth_phy_10g_rx_frame_sync - eth_phy_10g_rx_frame_sync_inst
      │   ├── eth_phy_10g_rx_ber_mon - eth_phy_10g_rx_ber_mon_inst
      │   └── eth_phy_10g_rx_watchdog - eth_phy_10g_rx_watchdog_inst
      └── xgmii_baser_dec_64 - xgmii_baser_dec_inst
  └── eth_phy_10g_tx - eth_phy_10g_tx_inst
      ├── xgmii_baser_enc_64 - xgmii_baser_enc_inst
      └── eth_phy_10g_tx_if - eth_phy_10g_tx_if_inst
          ├── lfsr - scrambler_inst
          └── lfsr - prbs31_gen_inst
```

Para obtener más información detallada sobre los bloques PCS, consulta la [documentación detallada en la Wiki](https://github.com/sofiavalos/Ethernet_10g_PCS/wiki/Bloques-PCS).

