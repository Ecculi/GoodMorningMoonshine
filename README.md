# GoodMorningMoonshine
Modern version of Spurgux

Suunnitelma ja päätökset: [DESIGN.md](DESIGN.md)

## Prototyypin ajaminen

1. Asenna [Godot 4.7](https://godotengine.org/download) (tavallinen versio, ei .NET).
2. Avaa Godotissa tämän kansion `project.godot` ja paina F5.

Ohjaus:

| Toiminto | Näppäimistö | Peliohjain | Puhelin |
|---|---|---|---|
| Liiku | nuolet / WASD | ristiohjain / vasen tatti | ruudun nuolet |
| Juokse | suunnan kaksoisnapautus tai pitäminen pohjassa | sama | sama |
| Lyö / juo / syö | välilyönti, Z tai Enter (lyhyt painallus) | A | iso nappi |
| Heitä käden tavara | sama nappi pohjassa | sama | sama |
| Puhelin auki / kiinni | P tai Tab | Y | puhelinnappi (pieni nappi ison napin yläpuolella) |
| Selaa puhelinta | vasen / oikea | sama | sama |

Debug (vain kehitysversiossa, esim. editorista ajettaessa): F1 health täyteen, F2 alkoholia +0,1 ‰ joka painalluksella (ei ylärajaa; yli 3,5 ‰:ssä hahmo sammuu), F3 rahaa +100 €, F4 puhelimen akkua +25 %. Samat napit näkyvät ruudun vasemmassa reunassa.
