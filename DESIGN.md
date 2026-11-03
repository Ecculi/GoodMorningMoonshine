# GoodMorningMoonshine – suunnitteludokumentti

Elävä dokumentti pelin suunnittelupäätöksistä. Päivitetään sitä mukaa, kun ideat tarkentuvat.

## Yleiskuva

GoodMorningMoonshine on Godot 4:llä tehtävä huumoripitoinen roguelike-henkinen toimintapeli. Inspiraationa on suomalaisen 1980-luvun roguelike-pelin lajityyppi ja mekaniikat, mutta peli on oma: hahmot, esineet, paikat, tarina ja huumori keksitään itse.

**Perusidea:** pelihahmo herää krapulassa ja huomaa hukanneensa tavaroitaan. Hänen pitää lähteä etsimään niitä kaupungilta, selvitä hengissä ja löytää takaisin kotiin.

## Kuvakulma ja grafiikka

- **Grafiikka toteutetaan tilt-shift-tekniikalla**, jolloin kaupunki näyttää pienoismallilta. *(Toteutustapa, eli 3D-maailma ja syväterävyys vai 2D ja jälkikäsittely, on vielä päättämättä.)*
- Kuvakulma on viisto sivukuva (beat 'em up / belt scroller -tyyli).
- Pelaaja etenee pääasiassa sivusuunnassa, mutta voi liikkua myös ylös ja alas kadun syvyyssuunnassa.

## Ajan kulku

- Peli on reaaliaikainen, mutta **aika etenee vain, kun pelaaja liikkuu tai tekee jotain**. Muuten peli on kuin pausella.

## Kartta ja kaupungit

- Tasot ovat katuja. Näkymä vierii jonkin verran vasemmalle ja oikealle.
- Kaduilla on risteyksiä, joista voi mennä ylös tai alas. Silloin näyttö vaihtuu ja tulee uusi katu.
- Jokainen peli sijoittuu johonkin kaupunkiin. Kaupungin kartta on aina sama, mutta **kodin sijainti vaihtuu joka pelissä**, mikä lisää uudelleenpelattavuutta.
- Kun pelaaja kuolee ja aloittaa uuden pelin, kaupunki ja kodin sijainti vaihtuvat.
- **Aluksi toteutetaan vain Oulu.**

## Pelin kulku

### Päivä = kenttä

1. Päivä alkaa kotoa. Pelaaja lähtee liikkeelle, joten hän tietää, missä koti on.
2. Osa tavaroista on hukassa, ja niitä etsitään kaupungilta.
3. Kotiin päästyään hahmo rojahtaa sänkyyn, sohvalle tai lattialle alkoholimäärästä ja väsymyksestä riippuen ja nukahtaa. Joskus pääsee pieru.
4. Seuraava päivä on uusi kenttä, ja se on aina edellistä vaikeampi.

### Hukatut tavarat

- Joka päivä hukkuu uusia tavaroita. Aiemmin hukatut pysyvät hukassa, kunnes ne löytyvät.
- Jokaisen puuttuvan tavaran puute haittaa peliä jollain tavalla. Esimerkkejä:
  - **Lompakko:** ei voi ostaa mitään. Ensimmäisenä päivänä lompakko voi olla hukassa.
  - **Puhelin**
  - **Silmälasit**
  - **Aurinkolasit**
  - **Vaatekappaleet**
  - **Avaimet**
  - *(lisää myöhemmin)*
- *Avoinna:* kunkin tavaran tarkka haittavaikutus.

## Hahmon tila

| Tila | Näyttötapa | Seuraus |
|---|---|---|
| **Health** | mittari | kuolema, kun nollassa |
| **Alkoholi** | mittari | kuolema, kun nollassa |
| **Väsymys** | mittari | nukahtaa, kun täynnä (ks. alla) |
| **Kylmä** | ei mittaria: hahmo tärisee | *avoinna* |
| **Nälkä** | ei mittaria: maha kurisee, hahmo näyttää nälkäiseltä | *avoinna* |

### Nukahtaminen väsymyksestä

- Kun väsymys on täynnä, pelaaja nukahtaa siihen paikkaan, missä on.
- Hän herää seuraavana aamuna, eli seuraavasta kentästä.
- Joskus hän herää samasta paikasta. Jos veressä oli tarpeeksi alkoholia, hän voi herätä aivan muualta, esimerkiksi toisesta asunnosta.

## Tappelu

- Pelissä on tappelua. Pelaaja voi lyödä muita, ja muut voivat hyökätä pelaajan kimppuun.

## Pisteytys

- Peli jatkuu päivästä toiseen, kunnes hahmo kuolee.
- Loppupisteet lasketaan:
  - **selvityistä päivistä** (antaa eniten pisteitä)
  - rahan määrästä
  - tavaroiden määrästä
- *Avoinna:* tarkka pistekaava ja se, onko pelillä läpäisyä.

## Tekniikka

- Pelimoottori: **Godot 4.7**
- *Avoinna:* GDScript vai C#.

## Avoimet kysymykset

- 3D vai 2D (vaikuttaa tilt-shiftin toteutukseen)
- GDScript vai C#
- Hukattujen tavaroiden haittavaikutukset
- Mistä alkoholia, ruokaa ja rahaa saa, varsinkin ilman lompakkoa
- Kylmän ja nälän pelilliset vaikutukset
- Viholliset ja muut kaupunkilaiset
- Oulun kartan laajuus ja tarkkuus (oikeat kadunnimet?)
- Pääseekö rakennuksiin sisälle
- Pelin läpäisy
