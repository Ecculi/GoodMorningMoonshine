# GoodMorningMoonshine – suunnitteludokumentti

Elävä dokumentti pelin suunnittelupäätöksistä. Päivitetään sitä mukaa, kun ideat tarkentuvat.

## Yleiskuva

GoodMorningMoonshine on Godot 4:llä tehtävä huumoripitoinen roguelike-henkinen toimintapeli. Inspiraationa on suomalaisen 1980-luvun roguelike-pelin lajityyppi ja mekaniikat, mutta peli on oma: hahmot, esineet, paikat, tarina ja huumori keksitään itse.

**Perusidea:** pelihahmo herää krapulassa ja huomaa hukanneensa tavaroitaan. Hänen pitää lähteä etsimään niitä kaupungilta, selvitä hengissä ja löytää takaisin kotiin.

**Peli on nopeatempoinen.** Mekaniikat, joissa vain odotetaan tai istutaan paikallaan, jätetään pois.

**Pelissä ei ole tupakkaa lainkaan.**

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
- **Yksi pelinäkymä on yksi kortteli**, eli kadun pätkä kahden risteyksen välillä. Risteykset ovat näkymän reunoilla.
  - Risteyksestä jatketaan suoraan samaa katua seuraavaan kortteliin (näkymä vaihtuu) tai käännytään ylös tai alas poikkikadulle (näyttö vaihtuu ja tulee uusi katu).
  - Lyhyet näkymät ovat kevyitä ladata myös mobiilissa ja selaimessa, ja jokaisella korttelilla voi olla oma tunnelmansa.
- **Korttelin ylittää noin 5 sekunnissa**, jos juoksee koko ajan. Kävellen siihen menee kauemmin.
- **Tavarat ovat lähellä kotia:** koko keskusta on käytössä, mutta koti ja hukatut tavarat arvotaan joka päivä muutaman korttelin säteelle toisistaan. **Säde kasvaa päivä päivältä**, mikä on yksi tapa, jolla peli vaikeutuu.
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
- Aluksi toteutettavat sisätilat:

  | Paikka | Mitä siellä on |
  |---|---|
  | **Kioski** | ruokaa, juomaa, puhelimen lataus |
  | **Baari / pubi** | alkoholia, portsari, tappeluita |
  | **Kauppahalli** | ruokaa; oikotie kahden kadun välillä |
  | **Kauppakeskus** | lämmittelyä, vartijoita, oikoteitä |
  | **Rautatieasema** | pistorasia, vartijat, lämmin odotussali |
  | **Kirkko** | rauhallinen lämmittelypaikka; pappi voi auttaa; sunnuntaisin ehtoollisviiniä |
  | **Kerrostalon rappu** | kodit, naapurit, varavaimet |

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
  - **Pelipäivän pituus on noin 3 minuuttia** oikeaa aikaa, jos pelaaja liikkuu koko ajan. Peli on nopea, ja yksi pelin tunti vastaa siis vain muutamaa sekuntia liikettä.
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

### Viikonpäivät ja rannekello

- Pelissä on viikonpäivät. **Ensimmäinen pelipäivä on satunnainen viikonpäivä**, eikä pelaaja tiedä, mikä se on.
- **Sunnuntaisin** (joka 7. pelipäivä) kirkossa on **ehtoollisviiniä**, eli ilmaista alkoholia.
- **Rannekello:** jos pelaaja saa varastettua jollekulta rannekellon, siitä näkee, mikä viikonpäivä on. Silloin hän tietää, milloin on sunnuntai.

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

## Rahan hankinta

- **Taskuvarkaus:** hahmo on kleptomaani ja näpistää automaattisesti (ks. Ryöstely).
- **Ryöstely:** tyrmätty ohikulkija voi pudottaa rahaa (ks. Ryöstely).
- **Pullonpalautus:** pantillisia tölkkejä ja pulloja kerätään kadulta ja palautetaan kioskissa tai kauppakeskuksessa. Tölkinkerääjä kilpailee samoista tölkeistä.
- **Kolikoita maasta:** näkyvät epäselvinä kuten muutkin esineet ja selkenevät lähelle mentäessä.
- **Katusoitto:** onnistuu, jos löytää soittimen tai pahvimukin.
- **Kerjäämistä ei toteuteta**, koska se on hidasta eikä sovi nopeatempoiseen peliin.

## Ruoan ja alkoholin hankinta

- **Ostaminen:** kioskista, baarista ja kauppahallista (vaatii lompakon ja rahaa).
- **Ryöstely ja taskuvarkaus:** ohikulkija voi pudottaa ruokaa tai alkoholia.
- **Kadun juoppo:** voi tarjota huikan vaihtokauppana.
- **Roskiksen penkominen:** nopea toiminto. Sieltä voi löytyä ruokaa, tölkki tai ei mitään, ja lokit voivat hyökätä.
- **Terassilta varastaminen:** pelaaja nappaa juoman pöydältä ohi kulkiessaan. Asiakas tai portsari voi suuttua.
- **Hukatut pullot ja eväät:** kadulla on muiden hukkaamia pulloja ja eväitä. Ne näkyvät epäselvinä kuten muutkin esineet.
- **Ehtoollisviini:** kirkossa sunnuntaisin (ks. Viikonpäivät ja rannekello).
- **Ilmaiset maistiaiset:** kauppahallissa tai kauppakeskuksessa, mutta **vain joskus** (satunnaista, ei joka päivä). Myyjä muistaa, jos käy hakemassa liian monta kertaa.

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
| Punkkarit | liikkuvat aina 2–3 hengen porukassa; jos lyöt yhtä, kaikki käyvät kimppuun; jos et ärsytä, voivat tarjota tölkin kaljaa |
| Taskuvaras | satunnaisesti joko törmää ohimennen ja vie rahaa tai tavaran (esim. puhelimen; takaisin vain kiinni saamalla tai tyrmäämällä, muuten tavara hukkuu taas) tai yrittää näpistää samaan aikaan kuin pelaaja, jolloin syntyy koominen kollegakohtaus ja kumpikin saa jotain |
| Portsari | seisoo baarin ovella ja arvioi kunnon: päästää sisään vain, jos alkoholia on sopivasti; liian humalaisen tai likaisen käännyttää; ilman kenkiä ei pääse sisään; rajatapauksissa rahalahjus auttaa; väkisin tunkeva heitetään kadulle (vie healthia) |
| Pappi | auttaja: antaa joskus pullaa tai kahvia kylmissään tai nälkäiselle; paheksuu humalaa mutta auttaa silti; jos häntä lyö, poliisit tulevat erityisen nopeasti |
| Poliitikko | tavallinen vaalityyppi, satunnaisesti jompikumpi: **vaalikoju** (jakaa ilmaista kahvia ja karkkia juttelijoille; lähellä ei saa näpistää tai tapella, koska kamerat ovat paikalla ja poliisit tulevat heti) tai **kättelijä** (ryntää kättelemään eikä hänestä pääse eroon; kättelyn aikana kleptomaani näpistää automaattisesti, usein lompakon sisältöä) |
| Muut kaupunkityypit | koira… (erikoisuudet keksitään) |

## Pisteytys

- Peli jatkuu päivästä toiseen, kunnes hahmo kuolee.
- Loppupisteet lasketaan:
  - **selvityistä päivistä** (antaa eniten pisteitä)
  - rahan määrästä
  - tavaroiden määrästä
- **Pelillä ei ole läpäisyä.** Peli jatkuu ja vaikeutuu, kunnes hahmo kuolee. Tavoitteena on selvitä mahdollisimman monta päivää ja saada parhaat pisteet.
- *Avoinna:* tarkka pistekaava.

## Tekniikka

- Pelimoottori: **Godot 4.7** (tavallinen versio, ei .NET/mono)
- Kieli: **GDScript**. Valittu, koska sillä peli voidaan viedä kaikille alustoille, myös selaimeen. Godot 4.7 ei tue C#-pelien vientiä selaimeen.
- Kohdealustat: **kaikki mahdolliset** (PC, mobiili, selain).

## Avoimet kysymykset

- Hukattujen tavaroiden haittavaikutukset
- Hahmojen erikoisuudet tarkemmin
- Lisää rakennuksia ja sisätiloja myöhemmin (aloituslista on päätetty)
