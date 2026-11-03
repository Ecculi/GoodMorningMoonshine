# GoodMorningMoonshine – suunnitteludokumentti

Elävä dokumentti pelin suunnittelupäätöksistä. Päivitetään sitä mukaa, kun ideat tarkentuvat.

## Yleiskuva

GoodMorningMoonshine on Godot 4:llä tehtävä huumoripitoinen roguelike-henkinen toimintapeli. Inspiraationa on suomalaisen 1980-luvun roguelike-pelin lajityyppi ja mekaniikat, mutta peli on oma: hahmot, esineet, paikat, tarina ja huumori keksitään itse.

**Perusidea:** pelihahmo herää krapulassa ja huomaa hukanneensa tavaroitaan. Hänen pitää lähteä etsimään niitä kaupungilta, selvitä hengissä ja löytää takaisin kotiin.

## Kuvakulma ja grafiikka

- **Grafiikka toteutetaan tilt-shift-tekniikalla**, jolloin kaupunki näyttää pienoismallilta.
- Peli tehdään **3D:nä**, koska tilt-shift syntyy siinä luontevimmin kameran syväterävyydellä (ylä- ja alareuna sumenevat).
- Kuvakulma on viisto sivukuva (beat 'em up / belt scroller -tyyli).
- Pelaaja etenee pääasiassa sivusuunnassa, mutta voi liikkua myös ylös ja alas kadun syvyyssuunnassa.

## Ajan kulku

- Peli on reaaliaikainen, mutta **aika etenee vain, kun pelaaja liikkuu tai tekee jotain**. Muuten peli on kuin pausella.
- Erillistä odota-toimintoa ei ole. Paikallaan seistessä ei tapahdu mitään, eikä hahmo esimerkiksi lämpene.
- Liikkuminen kuluttaa aina ruokaa, eli nälkä kasvaa.
- Pelaaja voi kävellä ja **juosta**.

## Kartta ja kaupungit

- Tasot ovat katuja. Näkymä vierii jonkin verran vasemmalle ja oikealle.
- Kaduilla on risteyksiä, joista voi mennä ylös tai alas. Silloin näyttö vaihtuu ja tulee uusi katu.
- Jokainen peli sijoittuu johonkin kaupunkiin. Kaupungin kartta on aina sama, mutta **kodin sijainti vaihtuu joka pelissä**, mikä lisää uudelleenpelattavuutta.
- Kun pelaaja kuolee ja aloittaa uuden pelin, kaupunki ja kodin sijainti vaihtuvat.
- **Aluksi toteutetaan vain Oulu.**

### Oulu

- Alue on **Oulun keskustan ruutukaava**: noin kauppatorin ja rannan (luoteessa) sekä rautatieaseman (idässä) välinen alue, etelässä suunnilleen Sepänkadulle asti.
- Kadut muodostavat kaksi ristikkäistä sarjaa (noin 9 × 9 katua), joten jokaisessa risteyksessä käännytään 90 astetta:
  - **Lounas–koillinen:** Rantakatu, Aleksanterinkatu, Torikatu, Kirkkokatu, Isokatu, Uusikatu, Mäkelininkatu, Koulukatu, Rautatienkatu
  - **Luode–kaakko:** Ojakatu, Hallituskatu, Pakkahuoneenkatu, Saaristonkatu, Albertinkatu, Sepänkatu (sekä idässä Asemakatu, Kajaaninkatu, Kauppurienkatu)
- **Maamerkit:** Kauppatori, kauppahalli, Rotuaari, tuomiokirkko, poliisiasema, rautatieasema, puistot (Snellmanin, Otto Karhin, Franzénin, Vaaranpuisto, Mannerheimin) ja kanava. Meri on luoteessa.
- Käytetään **oikeita kadunnimiä ja julkisia paikkoja**. **Yritysten nimet** (ravintolat, hotellit, kauppakeskukset) korvataan keksityillä nimillä.
- **Rakennuksiin pääsee sisälle**, esimerkiksi kioskiin ja rautatieasemalle.
- Osassa rakennuksista on ovet kahdelle eri kadulle. Ne toimivat **oikoteinä**: yhdestä ovesta sisään, toisesta ulos eri kadulle.
- Sisätiloissa pelimekaniikka on sama kuin kadulla (liikkuminen, tappelu, hahmot, tavarat). Ne vain näyttävät erilaisilta.
- Sisällä liikkuessaan hahmo **lämpenee hitaasti**. Pitkään ei kuitenkaan kannata lämmitellä, koska alkoholi laskee ja nälkä kasvaa.

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
  - **Puhelin:** ilman sitä ei saa vihjeitä eikä tiedä sijaintiaan (ks. alla).
  - **Silmälasit:** ilman niitä näkökenttä on lyhyempi (ks. alla).
  - **Aurinkolasit:** aurinkoisella säällä pelaaja ei juuri näe, kun kulkee aurinkoa vasten (ks. alla).
  - **Vaatekappaleet:**
    - Jokainen puuttuva vaatekappale saa hahmon kylmettymään nopeammin, ja kylmä kasvattaa taas nälkää nopeammin.
    - **Kengät:** ilman niitä vauhti on hitaampaa, ja juokseminen on mahdollista mutta vaikeampaa. Hyötynäkin on: paljain jaloin pelaaja voi **hiippailla**. Hiippaillen voi ohittaa poliisit ja vartijat huomaamatta, yllättää ohikulkijan selän takaa ja **taskuvarastaa** helpommin.
    - **Takki ja housut:** suojaavat tappeluissa.
  - **Avaimet:** ilman niitä kotiovi on lukossa. Kotiin pääsee silti muilla keinoilla, joista jokainen maksaa jotain:
    - **Naapurin ovikello:** naapuri voi päästää sisään, haukkua tai soittaa poliisille (satunnaista).
    - **Ikkuna tai parveke:** onnistuu, jos asunto on alakerrassa. Putoaminen vie healthia, ja ohikulkija voi luulla murtautujaksi ja hälyttää poliisit.
    - **Lukkoseppä:** vaatii puhelimen (akkua) ja lompakon (rahaa). Kallis, mutta varma.
    - **Varavain:** joskus kuramaton alla tai kaverilla toisella kadulla, jonka luo pitää löytää.
    - **Rappukäytävä:** hahmo nukahtaa oman oven taakse. Lasketaan muualla nukahtamiseksi: uni on huonompi ja hahmo on aamulla kylmissään.
  - *(lisää myöhemmin)*
- *Avoinna:* muiden tavaroiden tarkka haittavaikutus.

### Näkökenttä ja silmälasit

- Kentillä on kaikenlaista tavaraa, joka näkyy epäselvänä ja **selkenee vasta, kun sen lähelle menee**. Joskus se on hukattu tavara, joskus vain sitä muistuttava roska tai muu esine.
- **Ilman silmälaseja** tämä näkökenttä on lyhyempi.
- Ilman silmälaseja kadunnimistä ei saa selvää kuin aivan vierestä. Kirjaimet voivat jopa mennä sekaisin.

### Aurinko ja aurinkolasit

- Pelissä on aurinko, joka paistaa aina **tietystä ilmansuunnasta** kaupungin kartalla.
- Kadut ovat eri suuntiin, joten auringon suunta ruudulla riippuu kadusta. Jos aurinko näkyy taustalla talojen välistä ja pelaaja kääntyy risteyksestä 90 astetta toiselle kadulle, aurinko paistaa sen jälkeen sivulta, esimerkiksi oikealta.
- **Varjot** vaihtavat suuntaa samalla tavalla.
- Aurinko **liikkuu päivän mittaan** pelin kellon mukaan. Kello etenee vain, kun pelaaja liikkuu tai tekee jotain, joten aurinko etenee samassa tahdissa.
  - Häikäisy ja aurinkolasien tarve vaihtelevat kellonajan ja kadun suunnan mukaan.
  - Kellonajan näkee maailmasta, vaikka puhelin olisi hukassa.
  - Iltaa kohti tulee hämärää ja pimeää. **Mitä pimeämpää on, sitä nopeammin väsymys kasvaa.** Päivä päättyy siis luontevasti nukahtamiseen, jos kotiin ei ehdi.
  - **Mitä myöhemmin hahmo menee nukkumaan tai nukahtaa, sitä myöhemmin hän herää seuraavana päivänä**, kuten oikeastikin. Myöhäinen herätys jättää vähemmän valoisaa aikaa.
  - *Avoinna:* pelipäivän pituus, eli kuinka paljon liikettä vastaa yhtä tuntia.
- Aurinkoisella säällä pelaaja **ei juuri näe aurinkoa vasten kulkiessaan, jos aurinkolasit ovat hukassa**.

### Puhelin

- Puhelin auttaa vain **tavaroiden löytämisessä** ja **oman sijainnin selvittämisessä**.
- Käyttö on hyvin yksinkertaista: näkymiä selataan vain sivusuunnassa tässä järjestyksessä:
  1. **Viestit:** näkyvät vain lauseiden alut, kuten WhatsAppin listassa. Niistä saa vihjeitä siitä, missä hahmo oli eilen.
  2. **Viimeisin kuva:** kertoo, missä hahmo oli eilen. Kuvassa voi näkyä jokin hukattu tavara.
  3. **Kartta:** näyttää, missä hahmo on juuri nyt.
- **Akku:** virtaa on aina todella vähän. Akku kuluu koko ajan, kun puhelinta käytetään, ja mitä pidempään sitä käyttää, sitä enemmän akkua kuluu. Kartta kuluttaa akkua nopeimmin.
- Puhelinta käytettäessä **maailma on pysähdyksissä**, mutta akku kuluu.
- Akkua voi **ladata** esimerkiksi rautatieaseman pistorasiassa. Lataaminen on **vaihtokauppa**: aika harppaa hetken eteenpäin, puhelimeen tulee tietty määrä akkua (aina vain vähän), ja samalla alkoholi laskee ja nälkä kasvaa.
  - Muut hahmot liikkuvat harppauksen aikana, joten sen jälkeen tilanne on hieman eri. Muutos on realistinen eikä aina haasteellinen, koska pelaaja maksoi jo alkoholilla ja ruoalla.
- Viestien ja kuvien olemassaolo on **satunnaista**. Joka päivä hahmo ei välttämättä ole saanut viestejä tai ottanut kuvia.
- Kuvat ovat aina **todella huvittavia**. Niissä voi olla alastomuutta, mutta se on peitetty sumealla esineellä, joka on muka vahingossa osunut eteen.

## Hahmon tila

| Tila | Näyttötapa | Seuraus |
|---|---|---|
| **Health** | mittari | kuolema, kun nollassa |
| **Alkoholi** | mittari | kuolema, kun nollassa |
| **Väsymys** | mittari | nukahtaa, kun täynnä (ks. alla) |
| **Kylmä** | ei mittaria: hahmo tärisee | nälkä kasvaa nopeammin ja health kuluu |
| **Nälkä** | ei mittaria: maha kurisee, hahmo näyttää nälkäiseltä | health kuluu; alkoholi nostaa alkoholimittaria tavallista enemmän (tyhjään mahaan) |

### Nukahtaminen väsymyksestä

- Kun väsymys on täynnä, pelaaja nukahtaa siihen paikkaan, missä on.
- Hän herää seuraavana aamuna, eli seuraavasta kentästä.
- Joskus hän herää samasta paikasta. Jos veressä oli tarpeeksi alkoholia, hän voi herätä aivan muualta, esimerkiksi toisesta asunnosta.

## Tappelu

- Pelissä on tappelua. Pelaaja voi lyödä muita, ja muut voivat hyökätä pelaajan kimppuun.

### Ryöstely

- Ilman lompakkoa pelaaja voi hankkia tavaraa hakkaamalla ohikulkijoita.
- Tyrmätty ohikulkija pudottaa maahan satunnaisesti alkoholia, ruokaa, rahaa tai ei mitään. Joskus se pudottaa myös avaimen tai puhelimen.
- Ohikulkijoilta voi myös **taskuvarastaa** ilman tappelua.
  - Pelihahmo on **kleptomaani**: aina kun hänet ohjataan tarpeeksi lähelle jonkun selän taakse, hän yrittää **automaattisesti** näpistää tämän taskuista.
  - Joskus hän jää kiinni, joskus ei. Hiippailu (paljain jaloin) parantaa onnistumisen mahdollisuuksia.
  - Kiinni jäädessä näpistetty joko **alkaa tapella** tai **hälyttää poliisit ja/tai vartijat**.

### Poliisit ja vartijat

- Jos samalla kadulla on poliiseja tai vartijoita, ne käyvät pelaajan kimppuun, kun tämä hakkaa jotakuta.
- **Poliisit** yrittävät taltuttaa pelaajan. **Vartijat** yrittävät hakata hänet.
- Jos poliisit saavat pelaajan kiinni niin, ettei hän pääse karkuun, hän herää **putkasta**. Seuraava päivä alkaa sieltä, ja se on vaikeampi: alkoholia on hyvin vähän ja nälkä on kova.

## Hahmot

- **Ei koskaan lapsia.**
- Hahmot ovat tuttuja kaupunkityyppejä, joille keksitään omat erikoisuudet ja käytös. Alkuperäisen tunnusomaisia hahmoja ei kopioida.
- Vähemmistöjä tai sairauksia leimaavia hahmoja ei tehdä. Jokainen hahmotyyppi käyttäytyy kuten muutkin kaupunkilaiset, eikä mikään ryhmä ole olemassa vain hakattavaksi.

Hahmoideat:

| Hahmo | Erikoisuus |
|---|---|
| Ohikulkija | voi ryöstää (ks. yllä) |
| Poliisi | taltuttaa, vie putkaan |
| Vartija | hakkaa |
| Pyöräilijä, sähköpotkulautailija | väistettävä, törmää muuten |
| Turisti / muunkielinen ohikulkija | puhuu kieltä, jota hahmo ei ymmärrä; voi kysyä tietä tai yrittää auttaa |
| Ääripuolueen edustaja | jakaa lentolehtisiä, ei pääse eroon; aatetta ei kerrota |
| Mummo | hidas, lyö käsilaukulla yllättävän kovaa |
| Lokki | varastaa ruoan kädestä |
| Kadun juoppo | voi tarjota huikan vaihtokauppana |
| Tölkinkerääjä | kilpailija pantillisista tölkeistä |
| Some-vaikuttaja | kuvaa pelaajan; video "leviää" ja poliisit tunnistavat helpommin |
| Kerjäläinen | antaa rahaa vastaan vihjeen hukatusta tavarasta |
| Muut kaupunkityypit | punkkarit, taskuvaras, portsari, pappi, poliitikko, koira… (erikoisuudet keksitään) |

## Pisteytys

- Peli jatkuu päivästä toiseen, kunnes hahmo kuolee.
- Loppupisteet lasketaan:
  - **selvityistä päivistä** (antaa eniten pisteitä)
  - rahan määrästä
  - tavaroiden määrästä
- *Avoinna:* tarkka pistekaava ja se, onko pelillä läpäisyä.

## Tekniikka

- Pelimoottori: **Godot 4.7** (tavallinen versio, ei .NET/mono)
- Kieli: **GDScript**. Valittu, koska sillä peli voidaan viedä kaikille alustoille, myös selaimeen. Godot 4.7 ei tue C#-pelien vientiä selaimeen.
- Kohdealustat: **kaikki mahdolliset** (PC, mobiili, selain).

## Avoimet kysymykset

- Hukattujen tavaroiden haittavaikutukset
- Muut tavat saada alkoholia, ruokaa ja rahaa
- Hahmojen erikoisuudet tarkemmin
- Näytetäänkö katu kerrallaan kokonaan vai kortteli kerrallaan
- Mitä rakennuksia ja sisätiloja kaupungissa on
- Pelin läpäisy
