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
- **Terävä alue seuraa pelaajaa pystysuunnassa.** Kun hahmo liikkuu kadun syvyyssuunnassa ylös tai alas, tarkennuskaista siirtyy hänen mukanaan, joten hahmo on aina terävänä.
- Kuvakulma on viisto sivukuva (beat 'em up / belt scroller -tyyli).
- Pelaaja etenee pääasiassa sivusuunnassa, mutta voi liikkua myös ylös ja alas kadun syvyyssuunnassa.

## Ääni ja musiikki

- **Kaupungin äänet:** lokit, liikenne ja ihmisten puheensorina.
- **Hahmon ääntelyt:** ähkimistä, hikkaa ja mahan kurinaa.
- **Hiljainen taustamusiikki** soi koko ajan, ja se **horjuu humalatilan mukaan**.
- Sisätiloissa soi paikan oma musiikki, esimerkiksi baarissa ja kauppakeskuksessa.

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
- **Asiat eivät ole joka päivä samassa paikassa.** Kartta pysyy samana, mutta tavarat, ruoka, juomat, hahmot ja palvelut (esim. mistä saa kahvia) arvotaan joka päivä uudelleen. Eilen toimiva paikka ei välttämättä toimi tänään.
  - **Rakennukset ovat aina samoilla paikoilla**, koska ne ovat osa Oulun karttaa. Joka päivä arvotaan, **mitkä ovat auki ja mitä niissä on tarjolla** (esim. kioski voi olla kiinni tai baarissa eri portsari).

### Oulu

- Alue on **Oulun keskustan ruutukaava**: noin kauppatorin ja rannan (luoteessa) sekä rautatieaseman (idässä) välinen alue, etelässä suunnilleen Sepänkadulle asti.
- Kadut muodostavat kaksi ristikkäistä sarjaa (9 × 7 katua), joten jokaisessa risteyksessä käännytään 90 astetta:
  - **Lounas–koillinen** (luoteesta kaakkoon, tarkistettu kartasta): Rantakatu, Aleksanterinkatu, Torikatu, Kirkkokatu, Isokatu, Uusikatu, Mäkelininkatu, Koulukatu, Rautatienkatu
  - Kanava puistoineen (Otto Karhin puisto, Vaaranpuisto, Lyötynpuisto) kulkee Uusikadun ja Mäkelininkadun välissä. Vaarankatu on vain lyhyt katu kanavan varressa (ei vielä pelissä).
  - **Luode–kaakko** (koillisesta lounaaseen, tarkistettu kartasta): Asemakatu, Hallituskatu, Pakkahuoneenkatu, Kauppurienkatu (Rotuaari), Saaristonkatu, Albertinkatu, Sepänkatu
  - Vain idässä, Uusikadun itäpuolella: Kajaaninkatu, Linnankatu ja Heikinkatu (ei vielä pelissä)
  - **Ojakatu** on Hallituskadun ja kanavan välissä, vain Aleksanterinkadun ja Torikadun välillä. Asemakatu alkaa vasta Torikadulta; sen länsipuolella on kanava ja Madetojan puisto (ei vielä pelissä).
  - Pelin ruudukko olettaa toistaiseksi, että jokainen katu kulkee koko alueen läpi. Osittaiset kadut, puistot ja kanava vaativat myöhemmin tuen puuttuville kortteleille.
- **Kuvakulma kaduilla:** lounas–koillinen-kaduilla kamera katsoo luoteeseen (oikealle on koilliseen), luode–kaakko-kaduilla koilliseen (oikealle on kaakkoon). Risteyksessä ylös tarkoittaa poispäin kamerasta ja alas kohti kameraa. Siksi aurinko ja varjot kääntyvät kadun mukana.
- **Katukyltit risteyksissä:** tolpassa on kaksi kylttiä. Ylempi on oma katu, ja siinä on nuoli vasemmalle ja oikealle (katu jatkuu sivuille). Alempi on poikkikatu, ja siinä on nuoli ylös ja alas (siihen käännytään ylös tai alas).
- **Rantakadun pohjoispuolella on meri**, ja kartan reunoilla katu päättyy.
- Katujen järjestys on tiedostossa `scripts/city_map.gd`, jossa sitä on helppo korjata. *Avoinna:* osittaisten katujen (Ojakatu, Vaarankatu, Kajaaninkatu, Linnankatu, Heikinkatu) ja puistojen toteutus.
- **Maamerkit:** Kauppatori, kauppahalli, Rotuaari, tuomiokirkko, poliisiasema, rautatieasema, puistot (Snellmanin, Otto Karhin, Franzénin, Vaaranpuisto, Mannerheimin) ja kanava. Meri on luoteessa.
- Käytetään **oikeita kadunnimiä ja julkisia paikkoja**. **Yritysten nimet** (ravintolat, hotellit, kauppakeskukset) korvataan keksityillä nimillä.
- **Autoja liikkuu kaduilla harvakseltaan** (oikeanpuoleinen liikenne, satunnaisesti kumpaankin suuntaan). Autot pysähtyvät, jos joku (pelaaja tai muu hahmo) on suojatiellä, ja toisen auton taakse. Muualla tiellä kävelevän päälle auto ajaa. Pelaajalle käy satunnaisesti jompikumpi: **konepellille** (hahmo lennähtää konepellille, auto jatkaa 1–2,5 s ja jarruttaa, jolloin hahmo lentää kadulle ja menettää tajunnan hetkeksi) tai **yliajo** (hahmo kaatuu heti auton alle, eikä auto hidasta lainkaan). Kummassakin tulee vahinkoa, ruutu pimenee ja hahmo makaa tajuttomana noin 3 s. Ohikulkija kaatuu. Humalassa autoa on vaikeampi väistää. **Kävelykadulla (Rotuaari eli Kauppurienkatu) ei ole autoja lainkaan.**
- **Veteen voi pudota:** humalassa horjuva hahmo voi pudota rannasta, laiturilta tai kanavaan. Hän pääsee ylös, mutta on läpimärkä: **tulee todella kylmä**, ja vaatteet toimivat kuin ne olisivat hukassa, kunnes ne kuivuvat sisätiloissa. Kylmä vesi myös **piristää**, joten väsymys vähenee vähän. **Tavarat eivät huku** veteen pudotessa.
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
  | **Apteekki** | laastaria ja särkylääkettä rahalla; palauttaa vähän healthia |
  | **Kerrostalon rappu** | kodit, naapurit, varavaimet |

- Sisätiloissa pelimekaniikka on sama kuin kadulla (liikkuminen, tappelu, hahmot, tavarat). Ne vain näyttävät erilaisilta.
- Sisällä liikkuessaan hahmo **lämpenee hitaasti**. Pitkään ei kuitenkaan kannata lämmitellä, koska alkoholi laskee ja nälkä kasvaa.

## Pelin kulku

### Päivä = kenttä

1. **Ensimmäinen päivä alkaa kotoa**, joten pelaaja tietää, missä koti on. **Seuraavina päivinä hahmo herää aina jostain muualta** (juoppo on lähtenyt yöllä vielä liikkeelle), ja herätyspaikka on päivä päivältä kauempana kotoa. Näin jokainen päivä vaatii matkan kotiin, eikä pisteitä saa menemällä heti nukkumaan.
2. Osa tavaroista on hukassa, ja niitä etsitään kaupungilta.
3. Kotiin päästyään hahmo rojahtaa sänkyyn, sohvalle tai lattialle alkoholimäärästä ja väsymyksestä riippuen ja nukahtaa. Joskus pääsee pieru.
4. Seuraava päivä on uusi kenttä, ja se on aina edellistä vaikeampi.

### Koti

- **Kodin tyyppi vaihtelee** pelistä toiseen: esimerkiksi kerrostaloasunto (kerros arvotaan), kellarikomero tai kaverin sohva.

  | Koti | Erikoisuus |
  |---|---|
  | **Kerrostaloasunto** | tavallinen koti, paras uni. Ilman avaimia keinot ovat naapuri, ikkuna, lukkoseppä, varavain tai rappukäytävä (ks. Hukatut tavarat). |
  | **Kellarikomero** | kylmä: uni on huonompi ja aamulla ollaan vähän kylmissään. Ovessa on riippulukko, jonka voi rikkoa lyömällä, mutta se on meluisaa ja joku voi hälyttää poliisit. |
  | **Kaverin sohva** | avaimia ei tarvita, mutta ovikelloa pitää soittaa. Kaveri päästää sisään, jos tuo hänelle jotain (esim. juotavaa); muuten hän on joskus nukkumassa eikä avaa. |

### Vaikeutuminen

Päivät vaikeutuvat vähitellen kolmella tavalla:

- **Etsintäsäde kasvaa:** koti ja hukatut tavarat ovat kauempana toisistaan.
- **Enemmän hukattua:** joka päivä hukkuu useampi tavara.
- **Vaarallisempi kaupunki:** poliiseja, vartijoita, vihaisia koiria ja punkkariporukoita on enemmän.

Krapula ei kovene päivien mukaan.

**Ensimmäisenä päivänä** hukassa on **1–2 tavaraa**, jotta pelaaja oppii mekaniikat rauhassa. Yleensä ne ovat helppoja, kuten aurinkolasit, mutta joskus hukassa on lompakko.

### Hukatut tavarat

- **Ajatuskupla aamulla:** päivän alussa hahmon pään yläpuolelle tulee ajatuskupla, jossa näkyvät vain hukassa olevat tavarat (yliviivattuina). Kupla pysyy näkyvissä, kunnes pelaaja on kävellyt noin 5 metriä.
- Sen jälkeen **puuttuvat tavarat näkyvät koko päivän ruudun yläreunan keskellä** tekstin "Etsi:" perässä harmaina ikoneina. Löydetty tavara muuttuu värilliseksi ja saa vihreän rastin.
- **Löydetty oma tavara menee suoraan omalle paikalleen**: lompakko taskuun, kengät jalkaan ja niin edelleen. Harmaa ikoni muuttuu värilliseksi. Käden tavara ja pussi pysyvät ennallaan.
- **Humala vie muistin:** kun promillet nousevat tietyn rajan yli (esim. 2,0 ‰, tarkka raja säädetään testauksessa), hukkalistan ikoneita muuttuu yhtäkkiä tunnistamattomiksi harmaiksi läiskiksi. Pelaaja ei enää muista, mitä oli etsimässä. Kun promillet laskevat rajan alle, muisti palaa ja ikonit näkyvät taas.
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
  - **Henkilökortti:** ilman sitä baarissa ja kaupassa ei myydä alkoholia, ja poliisi pitää pidempään putkassa.
  - *(lisää myöhemmin)*
- *Avoinna:* muiden tavaroiden tarkka haittavaikutus.

### Tavara kädessä ja muovipussit

- **Kontrollit ovat helpot.** Tavarat poimitaan automaattisesti kävelemällä niiden päälle.
- Hahmolla on **yksi tavara kädessä**. Kun hän koskee uuteen tavaraan, käden tavara **vaihtuu automaattisesti** uuteen.
- Kadulla voi olla **muovipusseja**, jotka hahmo nappaa käteen automaattisesti päälle kävellessään.
- Kun pussi on kädessä, uudet tavarat **menevät pussiin**, eikä pussi vaihdu. Pussiin mahtuu muutama tavara, esimerkiksi tölkkejä pullonpalautukseen.
- Pussi voi **revetä**, jos siihen laittaa liikaa tai pelaaja tappelee. Silloin tavarat leviävät kadulle.
- **Kaikkia tavaroita voi heittää**, myös pussin tavaroineen.

### Kontrollit

- Kontrollien pitää olla niin simppelit, että peliä voi pelata **puhelimella**.
- Käytössä on vain **suuntanuolet** ja **yksi toimintanappi**.
- Toimintanapissa on **lyhyt ja pitkä painallus**:

  | Toiminto | Kontrolli |
  |---|---|
  | **Lyö** | lyhyt painallus |
  | **Syö / juo** käden tavara | lyhyt painallus, kun lähellä ei ole ketään |
  | **Mene sisään** | lyhyt painallus ovella |
  | **Heitä** käden tavara | pitkä painallus; mitä pidempään pitää pohjassa, sitä pidemmälle lentää. Latauksen aikana hahmo ei liiku, vaan nuolilla valitaan heiton suunta (myös ylös ja alas). Heitto lähtee, kun nappi päästetään. |
  | **Juokse** | kaksoisnapautus suuntanuolta tai saman suunnan pitäminen hetken pohjassa |
  | **Puhelin auki** | ylös + toimintanappi (kummassa järjestyksessä tahansa); näppäimistöllä myös P tai Tab |
  | **Puhelimen selaus** | vasen / oikea |
  | **Puhelin kiinni** | alas + toimintanappi |

### Näkökenttä ja silmälasit

- Kentillä on kaikenlaista tavaraa, joka näkyy epäselvänä ja **selkenee vasta, kun sen lähelle menee**. Joskus se on hukattu tavara, joskus vain sitä muistuttava roska tai muu esine.
- Kaukaa esineen **muoto vihjaa**, mitä se voi olla. Esimerkiksi kenkämäinen möykky voi olla omat kengät tai vanha saapas.
- **Omat tavarat eivät hehku eivätkä erotu muista** ennen kuin ne ovat lähellä. Pelaajan pitää tutkia epäilyttäviä möykkyjä.
- **Ilman silmälaseja** tämä näkökenttä on lyhyempi.
- **Ilman silmälaseja** kadunnimikyltit ovat sumeita, ja niistä saa selvää vasta aivan vierestä.
- **Humalassa** (yli 2 ‰) kyltin kirjaimet menevät sekaisin: yli 5 metrin päästä kyltissä on mitä sattuu kirjaimia. Lähempänä kuin 5 metriä kirjaimet ovat oikeat, mutta ne pyörivät uuteen järjestykseen jokaisella askeleella. **Jokaisella kyltillä on oma kohta** (eri kyltillä eri paikassa) kyltin lähellä: mitä lähempänä sitä kohtaa ollaan, sitä useampi kirjain on oikealla paikallaan, ja oikea nimi näkyy vasta aivan siinä kohdassa.
- Jos on humalassa ja lasit hukassa, molemmat efektit ovat voimassa.
- Sama koskee kauppojen kylttejä (kioski, baari).

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

### Sää

- **Joka päivä on eri sää**, ja se arvotaan satunnaisesti.
- **Aurinkoisella säällä kaduilla ja seinillä liikkuu pilvien varjoja.** Ne liikkuvat tuulen mukana vain silloin, kun aika kulkee, ja osuvat samaan suuntaan kuin auringon varjot.

  | Sää | Vaikutus |
  |---|---|
  | **Aurinkoinen** | häikäisee aurinkoa vasten kuljettaessa, jos aurinkolasit ovat hukassa |
  | **Pilvinen** | neutraali; aurinkolaseja ei tarvita |
  | **Sade** | kylmettyy nopeammin ilman takkia; lätäköitä, joista pyöräilijät roiskivat; näkyvyys hieman huonompi |
  | **Lumi ja pakkanen** | kova kylmä; liukkaat kadut, joten juostessa voi kaatua ja menettää healthia; kengättä erityisen vaikeaa |

### Puhelin

- Puhelin auttaa vain **tavaroiden löytämisessä** ja **oman sijainnin selvittämisessä**.
- Käyttö on hyvin yksinkertaista: näkymiä selataan vain sivusuunnassa tässä järjestyksessä:
  1. **Viestit:** näkyvät listana kuten WhatsAppissa. Viestit ovat **enimmäkseen emojeja ja pieniä kuvia**, ja välissä on muutama sana, kuten kadunnimi (esim. 🍺➡️ Kirkkokatu 👟❓). Niistä saa vihjeitä siitä, missä hahmo oli eilen.
  2. **Viimeisin kuva:** kertoo, missä hahmo oli eilen. Kuvassa voi näkyä jokin hukattu tavara.
  3. **Kartta:** näyttää, missä hahmo on juuri nyt ja missä koti on (talon kuva).
- **Akku:** virtaa on aina todella vähän. Akku kuluu koko ajan, kun puhelinta käytetään, ja mitä pidempään sitä käyttää, sitä enemmän akkua kuluu. Kartta kuluttaa akkua nopeimmin.
- Puhelinta käytettäessä **maailma on pysähdyksissä**, mutta akku kuluu.
- Kun akku loppuu, näytölle tulee hetkeksi vilkkuva tyhjän akun kuva, ja sitten puhelin sulkeutuu. Sama kuva näkyy, jos puhelimen yrittää avata tyhjällä akulla.
- Akkua voi **ladata** esimerkiksi rautatieaseman pistorasiassa. Lataaminen on **vaihtokauppa**: aika harppaa hetken eteenpäin, puhelimeen tulee tietty määrä akkua (aina vain vähän), ja samalla alkoholi laskee ja nälkä kasvaa.
  - Muut hahmot liikkuvat harppauksen aikana, joten sen jälkeen tilanne on hieman eri. Muutos on realistinen eikä aina haasteellinen, koska pelaaja maksoi jo alkoholilla ja ruoalla.
- Viestien ja kuvien olemassaolo on **satunnaista**. Joka päivä hahmo ei välttämättä ole saanut viestejä tai ottanut kuvia.
- Kuvat ovat aina **todella huvittavia**. Niissä voi olla alastomuutta, mutta se on peitetty sumealla esineellä, joka on muka vahingossa osunut eteen.

### Viikonpäivät ja rannekello

- Pelissä on viikonpäivät. **Ensimmäinen pelipäivä on satunnainen viikonpäivä**, eikä pelaaja tiedä, mikä se on.
- **Sunnuntaisin** (joka 7. pelipäivä) kirkossa on **ehtoollisviiniä**, eli ilmaista alkoholia.
- **Rannekello:** jos pelaaja saa varastettua jollekulta rannekellon, siitä näkee, mikä viikonpäivä on. Silloin hän tietää, milloin on sunnuntai.

## Pelattava hahmo

- Pelin alussa valitaan **mies tai nainen**. Valinta ei vaikuta pelimekaniikkaan.
- **Vaatetus vaihtelee** myöhemmin, mutta sitä ei toteuteta vielä ensimmäisessä versiossa.

## Hahmon tila

| Tila | Näyttötapa | Seuraus |
|---|---|---|
| **Health** | sydän, josta väri valuu pois; ei tarkkaa lukemaa | kuolema, kun nollassa |
| **Alkoholi** | **tarkka lukema promilleina** (esim. 1,4 ‰) pulloikonin sisällä, koska alkoholi on pelin tärkein muuttuja | kuolema, kun nollassa |
| **Väsymys** | ei mittaria: silmät alkavat painua kiinni, ryhti lysähtää, hahmo haukottelee ja päästä nousee välillä Zzz-ikoni | nukahtaa, kun täynnä (ks. alla) |
| **Kylmä** | ei mittaria: hahmo tärisee | nälkä kasvaa nopeammin ja health kuluu |
| **Nälkä** | ei mittaria: maha kurisee, hahmo näyttää nälkäiseltä | health kuluu; alkoholi nostaa alkoholimittaria tavallista enemmän (tyhjään mahaan) |

### Promillerajat

| Promillet | Tila |
|---|---|
| **0 ‰** | kuolema |
| **alle 0,5 ‰** | krapula: hahmo tärisee, lyönnit ovat heikkoja ja health kuluu hitaasti. Varoitus, että juotavaa pitää löytää. |
| **0,5–2,0 ‰** | sopiva alue, hahmo toimii normaalisti |
| **2,0–3,5 ‰** | humalan haitat (horjuminen, sumea näkökenttä, rohkeus) voimistuvat vähitellen |
| **yli 3,5 ‰** | hahmo sammuu |

- Promillet laskevat tasaisesti, kun pelaaja liikkuu tai tekee jotain.

### Uni ja aamun lähtötilanne

- **Aamun promillet riippuvat siitä, kauanko hahmo ehti nukkua.** Lyhyt uni jättää enemmän promilleja vereen, pitkä uni vähemmän. Myös nukkumaan mennessä veressä olleet promillet vaikuttavat.
- **Unen pituuteen ja laatuun vaikuttavat monet tekijät**, esimerkiksi:
  - **Paikka:** kotona sängyssä nukkuu parhaiten. Pihalla, rappukäytävässä tai putkassa uni jää lyhyeksi.
  - **Kylmä ja nälkä** heikentävät unta.
  - **Nukkumaanmenoaika:** mitä myöhemmin, sitä myöhemmin herätään (ks. Aurinko).
- Esimerkiksi pihalta herännyt on nukkunut lyhyesti, joten hänellä on aamulla enemmän promilleja veressä.
- **Uni laskee promilleja aina vähintään 0,6 ‰**, mutta aamu ei ala alle 0,25 promillesta (muuten päivä päättyisi heti).
- **Uni aiheuttaa nälkää.** Kylmä yö (katu, rappu, kellari) kasvattaa nälkää enemmän.
- **Unen laatu vaikuttaa kaikkeen:**
  - **Health:** hyvä yö kotona palauttaa healthin lähes täyteen, huono yö vähemmän.
  - **Väsymys** nollautuu yön aikana **lähes kokonaan** aina. Huonon yön jälkeen jää vain pieni jäännös.

### Healthin palautuminen

- **Uni:** yöunet palauttavat suurimman osan. Kotona nukkuminen palauttaa eniten.
- **Ruoka:** syöminen palauttaa vähän.
- **Apteekki:** laastaria tai särkylääkettä saa rahalla, mutta ne palauttavat vain vähän.
- Päivän aikana health ei palaudu itsestään.

### Väsymyksen vähentäminen

- **Kahvi ja energiajuoma** vähentävät väsymystä hetkeksi. Niitä löytää **harvoin**.
- Liika kofeiini saa hahmon tärisemään, jolloin lyönnit menevät ohi.

### Humala

Mitä enemmän alkoholia, sitä voimakkaammin nämä vaikuttavat:

- **Horjuminen:** ohjaus ei mene aivan suoraan, ja lyönnit menevät joskus ohi.
- **Hikka (yli 1,5 ‰):** hahmo hikkaa välillä ("hik!") ja nytkähtää. Hikan hetkellä taskuvarkaus paljastuu aina.
- **Rakkaus kaikkiin (2,0–2,5 ‰):** hahmo halaa ohikulkijoita, joihin törmää. Halauksen aikana taskuvarkaus onnistuu lähes aina, eikä halattu suutu.
- **Laulaminen (yli 2,2 ‰):** hahmo alkaa välillä laulaa (nuotteja nousee). Lähellä olevat ohikulkijat voivat suuttua, ja poliisit voivat huomata.
- **Rohkeus ja ohilyönnit (yli 2,0 ‰):** lyönnit tekevät tuplavahinkoa, mutta menevät sitä useammin ohi, mitä kovempi humala. Poliisit ja vartijat huomaavat rikoksen kaksi kertaa kauempaa myös hiippaillessa.
- **Kaatuilu:** hahmo voi kaatua vain, kun alusta vaihtuu (reunakiven yli ajotieltä jalkakäytävälle tai takaisin) tai kun hän kävelee jotain päin (puu, lyhtypylväs, penkki, roskis, kyltin tolppa). Kaatuminen on satunnainen yllätys: reunakiven ylityksessä 2 % (2,0 ‰) – 15 % (3,5 ‰), esteeseen törmätessä 8 % – 35 %; juostessa 1,5-kertaisesti ja lumella lisää 5 prosenttiyksikköä (kengättä 10). Selvin päin kuivalla kadulla hahmo vain törmää esteeseen ja pysähtyy. Esteiden läpi ei voi kävellä.
- **Tuplanäkö (yli 3,0 ‰):** kuva näkyy kahtena.
- **Krapula (alle 0,5 ‰):** hahmo tärisee, ja joka toinen lyönti on niin heikko, ettei se tee vahinkoa.
- **Hassu kävely:** kunnon humalassa (yli 2,5 ‰, voimakkaimmillaan noin 3,2 ‰) hahmo kävelee absurdin liioitellusti: korkeita potkuja eteen, heiluvat kädet, pomppiva askel ja taaksepäin kallistuva vartalo.
- **Väärä suunta:** kovassa humalassa (yli 2,5 ‰) hahmo lähtee välillä aivan eri suuntaan kuin nuoli osoittaa (esim. oikealle painettaessa ylös). Pelaaja voi korjata heti painamalla siihen suuntaan, johon hahmo oikeasti menee. Jos hän vain jatkaa alkuperäisen nuolen painamista, väärä suunta menee ohi itsestään noin 1,5–3 sekunnissa. Mitä kovempi humala, sitä useammin näin käy, ja **juostessa paljon useammin** kuin kävellessä. Väärä suunta voi olla mikä tahansa kahdeksasta suunnasta (myös viistoon), mutta **ei koskaan suoraan vastakkainen**. Jos väärä suunta veisi seinää tai reunaa päin, se peruuntuu, jottei hahmo jää kävelemään paikallaan.
- **Rohkeus:** lyönnit ovat kovempia ja kylmä tuntuu vähemmän, mutta poliisit huomaavat pelaajan helpommin.
- **Näkökenttä:** yli 2,0 promillessa kuva sumenee: pelihahmon ympärillä olevan ympyrän sisällä vähän, ulkopuolella enemmän, ja sitä enemmän mitä kovempi humala. Ympyrä pienenee nopeasti koko ruudun kokoisesta (2,0 ‰) 1,5 metrin säteeseen (3,0 ‰ ja enemmän), ja yli 3,0 promillessa sumennus ympyrän ulkopuolella voimistuu selvästi. Hahmon lähellä kuva pysyy selvimpänä.
- **Sammuminen:** kun alkoholimittari on täynnä, hahmo sammuu paikalleen. Se lasketaan nukahtamiseksi.

### Nukahtaminen väsymyksestä

- Kun väsymys on täynnä, pelaaja nukahtaa siihen paikkaan, missä on.
- Hän herää seuraavana aamuna, eli seuraavasta kentästä.
- Hän herää aina jostain muualta kuin kotoa (ks. Päivä = kenttä). Nukahtamispaikka vaikuttaa silti aamun promilleihin, healthiin ja nälkään.

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
- **Erillistä torjuntaa ei ole.** Iskuja voi väistää liikkumalla, esimerkiksi ylös tai alas kadun syvyyssuunnassa.
- Osalla hahmoista isku näkyy hetkeä ennen osumaa (esim. käsi nousee), mutta **kaikista hahmoista ei näe, milloin ne ovat lyömässä**.
- **Heittäminen:** heitetyn esineen vaikutus riippuu esineestä:
  - **Kevyt esine** (tölkki, tyhjä muovipussi) ärsyttää kohdetta mutta ei juuri satuta.
  - **Raskas esine** (pullo, täysi pussi) tainnuttaa kohteen hetkeksi.
  - **Ruoka** houkuttelee lokit ja koirat paikalle. Sillä voi harhauttaa vihaisen koiran.

### Ryöstely

- Ilman lompakkoa pelaaja voi hankkia tavaraa hakkaamalla ohikulkijoita.
- Tyrmätty ohikulkija pudottaa maahan satunnaisesti alkoholia, ruokaa, rahaa tai ei mitään. Joskus se pudottaa myös avaimen tai puhelimen.
- Tyrmätty ei katoa: hetken päästä hän nousee ylös ja nilkuttaa pois korttelista. Uudelleen tyrmättynä hän ei enää pudota mitään.
- Ohikulkijoilta voi myös **taskuvarastaa** ilman tappelua.
  - Pelihahmo on **kleptomaani**: aina kun hänet ohjataan tarpeeksi lähelle jonkun selän taakse, hän yrittää **automaattisesti** näpistää tämän taskuista.
  - Joskus hän jää kiinni, joskus ei. Hiippailu (paljain jaloin) parantaa onnistumisen mahdollisuuksia.
  - Kiinni jäädessä näpistetty joko **alkaa tapella** tai **hälyttää poliisit ja/tai vartijat**.

### Poliisit ja vartijat

- Jos samalla kadulla on poliiseja tai vartijoita, ne käyvät pelaajan kimppuun, kun tämä hakkaa jotakuta.
- **Poliisit** yrittävät taltuttaa pelaajan. **Vartijat** yrittävät hakata hänet.
- Jos poliisit saavat pelaajan kiinni niin, ettei hän pääse karkuun, hän herää **putkasta**. Seuraava päivä alkaa sieltä, ja se on vaikeampi: alkoholia on hyvin vähän ja nälkä on kova.
  - **Takavarikko:** poliisi ottaa käden tavaran ja pussin, ja ne jäävät poliisiasemalle. Lompakon ja puhelimen saa vapautuessa takaisin.
    - Muut takavarikoidut tavarat voi **hakea poliisiasemalta henkilökortilla**. Ilman korttia ne jäävät sinne, kunnes kortti löytyy.
  - Ilman henkilökorttia putkassa pidetään pidempään, joten seuraava päivä alkaa myöhemmin.
  - **Sellikaveri:** putkassa on joskus joku, joka satunnaisesti joko antaa vihjeen hukatusta tavarasta tai varastaa jotain.

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
| Koira | noin **20 eri rotua**. **Irtokoira** on haistaja: seuraa pelaajaa, jos tällä on ruokaa; joskus vie ruoan, joskus johdattaa hukatun tavaran luo hajun perusteella. Irtokoira voi olla **vihainen** (hyökkää) tai **kiltti**. **Hihnassa oleva koira** on vahtikoira: haukkuu, kun pelaaja yrittää näpistää omistajalta, jolloin kiinni jäämisen riski kasvaa. **Rotu vaikuttaa käytökseen:** kokoon, nopeuteen ja siihen, kuinka todennäköisesti koira on vihainen tai kiltti (pieni koira on nopea mutta vaaraton, iso hidas mutta lyö kovaa). Pelaaja oppii tunnistamaan vaaralliset rodut ulkonäöstä |
| Muut kaupunkityypit | (lisätään myöhemmin) |

## Kuolema

- Kuolema esitetään **paikallislehden lööppinä**, jossa on hahmon kuva ja humoristinen otsikko kuolinsyystä, esimerkiksi "Lokki vei viimeisen makkaran – nälkä voitti". Lehden nimi on keksitty.
- Sen jälkeen näytetään **pisteet ja ennätyslista**.
  - Ennätyslista on aluksi **vain omalla laitteella**. **Yhteinen maailmanlaajuinen lista** lisätään myöhemmin; se vaatii palvelimen ja huijauksen eston.
- Uusi peli alkaa **heti napin painalluksella**, jotta tahti pysyy nopeana.

## Pisteytys

- Peli jatkuu päivästä toiseen, kunnes hahmo kuolee.
- Loppupisteet lasketaan:
  - **selvityistä päivistä** (antaa eniten pisteitä)
  - rahan määrästä
  - tavaroiden määrästä
- **Pelillä ei ole läpäisyä.** Peli jatkuu ja vaikeutuu, kunnes hahmo kuolee. Tavoitteena on selvitä mahdollisimman monta päivää ja saada parhaat pisteet.
- **Pistekaava:**
  - **Selvitty päivä:** päivän numero × 1000. Esimerkiksi päivä 5 antaa 5000 pistettä, koska myöhemmät päivät ovat vaikeampia.
  - **Raha:** 100 pistettä jokaisesta eurosta.
  - **Tavarat:** 100 pistettä jokaisesta tavarasta, joka on mukana kuollessa.
  - **Bonus:** 500 pistettä, jos pääsee kotiin ja kaikki sen päivän hukatut tavarat on löydetty.

## Pelin opettaminen

- Erillistä opetusosiota ei ole.
- **Vihjeet näkyvät vain pelin ensimmäisenä päivänä**: pieniä ikonivihjeitä oikealla hetkellä, esimerkiksi oven kohdalla napin kuva ja nuoli sisään tai ensimmäisen esineen kohdalla kävelevä jalka. Kukin vihje näkyy kerran.
- Vihjeet näkyvät **jokaisen pelin ensimmäisenä päivänä**, mutta **ei uudelleen saman peli-istunnon aikana**. Jos pelaaja kuolee ja aloittaa uuden pelin sovellusta sulkematta, vihjeitä ei näytetä. Kun sovellus käynnistetään uudelleen, ne näkyvät taas.

## Kieli ja teksti

- Pelissä on **mahdollisimman vähän tekstiä**. Tapahtumat ja tilat selitetään **ikoneilla ja muodoilla**.
- Ensimmäinen kieli on **suomi**.
- Peli tehdään alusta asti **helposti lokalisoitavaksi** usealle kielelle: kaikki tekstit ovat käännöstiedostoissa (Godotin käännösjärjestelmä), eikä tekstiä kirjoiteta suoraan koodiin tai kuviin.
- Oulun kadunnimet pysyvät suomeksi kaikissa kieliversioissa.

## Tallennus

- Peli **tallentuu automaattisesti joka aamu** päivän alussa.
- Jos sovellus suljetaan kesken päivän, jatketaan **saman päivän alusta**.
- Kesken päivän ei voi tallentaa, joten huijaaminen ei onnistu.

## Tekniikka

- Pelimoottori: **Godot 4.7** (tavallinen versio, ei .NET/mono)
- Kieli: **GDScript**. Valittu, koska sillä peli voidaan viedä kaikille alustoille, myös selaimeen. Godot 4.7 ei tue C#-pelien vientiä selaimeen.
- Kohdealustat: **kaikki mahdolliset** (PC, mobiili, selain).

## Ensimmäinen prototyyppi

Tavoite: nähdä nopeasti, tuntuuko peli hyvältä, myös puhelimella. Prototyypissä on:

- **Yksi Oulun kortteli** 3D:nä (Kirkkokatu Pakkahuoneenkadun ja Hallituskadun välillä), risteykset näkymän reunoilla ja **tilt-shift-efekti**
- **Hahmo**, joka kävelee ja juoksee (kaksoisnapautus tai suunnan pitäminen pohjassa)
- **Toimintanappi** (lyhyt: lyö / juo / syö, pitkä: heitä)
- **Muutama ohikulkija**: tappelu, tyrmäys ja pudotukset sekä automaattinen taskuvarkaus
- **Tavarat**: pullo, tölkki, makkara ja kolikot; automaattinen poiminta ja käden tavaran vaihto
- **Promillemittari** pulloikonissa, healthin sydän ja raha
- Aika kulkee vain liikkuessa; aurinko liikkuu kellon mukaan
- Kuolema lööppinä ja päivän vaihtuminen (herätään samasta korttelista)
- Kosketusohjaimet puhelimelle, näppäimistö ja peliohjain muille alustoille
- Tekstit käännöstiedostossa (suomi)

Lisätty prototyyppiin:

- **Oulun keskustan kartta:** kaikki korttelit 9 × 7 kadun ruudukossa. Korttelin päästä jatketaan seuraavaan kortteliin, ja risteyksestä käännytään ylös tai alas poikkikadulle. Kadunnimikyltit ovat risteysten kulmissa. Korttelien ulkonäkö arvotaan, mutta sama kortteli näyttää aina samalta.
- Kadulle jääneet tavarat pysyvät korttelissa saman päivän ajan. Seuraavana aamuna sisältö arvotaan uudelleen.
- Uusi peli alkaa satunnaisesta korttelista. Seuraava päivä alkaa siitä korttelista, johon hahmo nukahti.

- **Koti ja hukatut tavarat:** kodin paikka (kerrostalo, vihreä ovi) arvotaan joka peliin, ja ensimmäinen päivä alkaa kodin ovelta (myöhemmin herätään muualta). Aamulla hukatut tavarat näkyvät hahmon ajatuskuplassa ensimmäisten 5 metrin ajan ja sen jälkeen ylhäällä keskellä "Etsi:"-listassa; humalassa osa ikoneista muuttuu läiskiksi. Tavarat arvotaan kodin lähelle säteellä, joka kasvaa päivä päivältä. Kaukaa ne ovat harmaita möhkäleitä, ja ilman silmälaseja ne erottuvat vasta aivan läheltä. Kotiovella toimintanappi vie nukkumaan, ja kotona nukuttu yö on paras. Ilman avaimia hahmo nukkuu rappukäytävässä, ja ilman kenkiä vauhti on hitaampi. Kun kaikki tavarat löytyvät ennen kotiin menoa, saa 500 pisteen bonuksen.

- **Sää:** joka päivä arvotaan aurinkoinen (liikkuvat pilvien varjot), pilvinen (pehmeä valo), sade (pisarat, harmaa valo, sumu) tai lumi ja pakkanen (hiutaleet, lumikerros kaduilla, reunakiven yli tai esteeseen törmätessä voi liukastua, kengättä helpommin). Sade ja lumi pysähtyvät ilmaan, kun aika on pysähdyksissä.
- **Kylmä:** ei mittaria; hahmo tärisee, kun on kylmissään. Kylmä kasvaa sateella ja pakkasella, ilman takkia ja märillä/kylmillä jaloilla nopeammin; aurinkoisella säällä hahmo lämpenee. Kylmissään nälkä kasvaa 1,5-kertaisesti, ja kova kylmä kuluttaa healthia. Humalassa (yli 2 ‰) kylmä tuntuu vähemmän. Kioskissa ja baarissa lämpenee, mutta aika kuluu sillä aikaa. Aamun kylmyys riippuu yöpaikasta.

- **Kotityypit:** kerrostaloasunto (ilman avaimia rappukäytävä), kellarikomero (ilman avaimia riippulukko rikotaan kolmella lyönnillä; kylmä yö) ja kaverin sohva (ovikello; juoma kädessä pääsee aina sisään, muuten kaveri nukkuu joskus eikä avaa sinä päivänä).
- **Tavaroiden haitat:** ilman silmälaseja kadunnimikyltit ovat sumeita (humalassa kirjaimet myös menevät sekaisin), ilman aurinkolaseja aurinko häikäisee aurinkoisella säällä, ilman takkia lyönnit sattuvat 30 % enemmän ja paljain jaloin taskuvarkaus onnistuu paremmin.

- **Puhelin:** ylös + toimintanappi avaa, vasen/oikea selaa, alas + toimintanappi sulkee. Viestit (tavaran ikoni ja kadunnimen alku), eilinen kuva (katukyltti ja hukattu tavara, hahmon edessä "sattumalta" sumea esine) ja kartta (pohjoinen ylhäällä, oma sijainti ja koti). Akkua on aamulla vähän, ja se kuluu reaaliajassa; kartta kuluttaa eniten. Maailma on pysähdyksissä puhelimen ollessa auki.
- **Kioski ja baari:** joissain kortteleissa (valaistu ovi ja kyltti), auki tai kiinni päivästä riippuen. Kioskista pullo (3 €), makkara (2 €) ja puhelimen lataus (ilmainen, mutta aika harppaa ja promillet laskevat). Baarissa tuoppi (5 €), ja ovella on portsari. Ostaminen vaatii lompakon ja alkoholi henkilökortin.
- **Nälkä:** kasvaa liikkuessa ja yöllä, kova nälkä kuluttaa healthia ja tyhjään mahaan alkoholi nousee 40 % enemmän. Ei mittaria: hahmosta nousee välillä vatsan kuva (maha kurisee), ja hahmo lysähtää. Makkara vie nälkää.

- **Poliisit ja vartijat:** poliiseja partioi osassa kortteleita (todennäköisyys kasvaa päivä päivältä, myöhemmin joskus pareittain), vartijoita seisoo kauppojen lähellä. Kun pelaaja lyö jotakuta tai heittää jollekulle pullon, korttelin poliisit lähtevät perään ja vartijat käyvät kimppuun. Epäonnistuneen taskuvarkauden uhri joko tappelee tai huutaa apua, jolloin poliisi voi juosta paikalle korttelin päästä. Paljain jaloin poliisit ja vartijat huomaavat rikoksen vain läheltä (7 m). Poliisin lyöminen vain horjuttaa hetkeksi. Kun poliisi pysyy pelaajan vieressä, ruudulle täyttyy sini-punainen rengas; täynnä oleva rengas vie putkaan. Toiseen kortteliin juoksemalla tai karkaamalla kauas pääsee pakoon.
- **Putka ja poliisiasema:** poliisiasema on Isokadulla Pakkahuoneenkadun ja Hallituskadun välissä (POLIISI-kyltti). Putkayön jälkeen herätään aseman ovelta: alkoholia 0,3 ‰ ja kova nälkä. Käden tavara takavarikoidaan; sen saa takaisin aseman ovelta henkilökortilla. Ilman henkilökorttia herätään kaksi tuntia myöhemmin. Sellikaveri joko kertoo, millä kadulla jokin hukattu tavara on, tai vie puolet rahoista.

- **Väsymys:** kasvaa liikkuessa, juostessa ja illalla pimeällä nopeammin (klo 20 jälkeen kaksinkertaisesti, klo 22 jälkeen kolminkertaisesti). Ei mittaria: silmät painuvat kiinni, hahmo lysähtää ja päästä nousee välillä Zzz. Täynnä hahmo nukahtaa siihen paikkaan. Aamulla väsymys on lähes nolla (kotona 0, kaverilla 5, muualla 15).
- **Kahvi ja energiajuoma:** löytyvät harvoin kadulta; energiajuomaa saa kioskista (3 €). Kahvi vie väsymystä 35, energiajuoma 45. Kaksi kofeiinijuomaa lyhyessä ajassa saa hahmon tärisemään 20 sekunniksi, jolloin lyönnit menevät usein ohi.

- **Fysiikka (rätkänukke):** kaatumisissa ja osumissa hahmo muuttuu hetkeksi fysiikalla liikkuvaksi rätkänukeksi (raajat nivelillä), joka lentää, pyörii ja lysähtää maahan; sen jälkeen hahmo nousee siitä, mihin päätyi. Koskee pelaajaa (auton töytäisy ja yliajo, kompastuminen, liukastuminen) ja ohikulkijoita, poliiseja ja vartijoita (tyrmäys, auton alle jääminen). Kävely ja ohjaus pysyvät tavallisina. Fysiikka pysähtyy, kun pelin aika pysähtyy. Fysiikkamoottori on Jolt.

Prototyypistä puuttuu vielä muun muassa hukatut tavarat, puhelin, nälkä, kylmä, väsymys, sää, poliisit ja muut hahmotyypit sekä sisätilat.

## Avoimet kysymykset

- Hukattujen tavaroiden haittavaikutukset
- Hahmojen erikoisuudet tarkemmin
- Lisää rakennuksia ja sisätiloja myöhemmin (aloituslista on päätetty)
