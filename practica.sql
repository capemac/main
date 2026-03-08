-- Práctica Data WareHouse & SQL
-- Adolfo Capellades
/*
Enunciado 1.
Explora el fichero flights y analiza:

Respuesta:
1.​ Cuántos registros hay en total              : 1209 
2.​ Cuántos vuelos distintos hay                :  266

*/


 select 
		count(flight_row_id ) as total_flights,
		count(distinct unique_identifier) as total_unique_flights
   from flights 
   ;

/*
3.​ Cuántos vuelos tienen más de un registro    :  250
*/
with flights_mto_rec as (
 select 
		unique_identifier,
		count(unique_identifier )
   from flights 
   group by unique_identifier 
   having count(unique_identifier) > 1
)
 select 
 		count(unique_identifier)
   from flights_mto_rec
   ;


/*
Enunciado 2.
Por qué hay registro duplicados para un mismo vuelo. Para ello, selecciona varios vuelos y
analiza la evolución temporal de cada vuelo.

Respuesta:
Los registros duplicados pertenecen a actualizaciones que se producen, en aquellos vuelos con más de un registro, cada 6 horas.

1.​ Qué información cambia de un registro a otro
    Los campos que suelen cambiar en dichas actualizaciones son los siguientes: 
    - local_actual_departure
    - local_actual_arrival
    - gmt_actual_departure
    - gmt_actual_arrival
    - delay_mins 
    - updated_at 
*/

select 
		*
   from flights
  where unique_identifier in ('AA-101-20240219-JFK-MAD', 'AR-140-20240120-EZE-MAD', 'IB-165-20240510-MAD-BCN')
 ;

/*
Enunciado 3.
Evalúa la calidad del dato. La calidad del dato nos indica si la información es consistente,
completa, coherente y representa una realidad verosímil. Para ello debemos establecer
unos criterios:


1.​ La información de created_at debe ser única para cada vuelo aunque tenga más de
un registro.
Respuestas: 
    Para los registros que tienen informados el campo created_at, la información es la misma para cada vuelo. Esto puede verse en count_distinct_created_at, en donde solamente hay un dato (misma fecha). 
*/
 select 
 		unique_identifier, 
 		count(distinct created_at) count_distinct_created_at,
 		count(distinct pg_typeof(created_at)) count_typeof_created_at
   from flights
  group by unique_identifier
  ;
/*
2.​ La información de updated_at deber ser igual o más que la información de
created_at, lo que nos indica coherencia y consistencia

Respuesta:
    La operación de ventana realizada entre updated_at y created_at muestra coherencia en los datos, es decir que updated_at es mayor o igual que created_at.
*/

with flight_upd_interval as (
	select 
		unique_identifier,
		local_departure, 
		local_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		created_at,
		updated_at,
		updated_at - 
		lag(created_at) over(partition by unique_identifier order by updated_at asc) as update_interval
	   from flights
	  order by unique_identifier, local_departure, updated_at
)
 select 
		*
   from flight_upd_interval
  where updated_at is not null

/*Enunciado 4.
El último estado de cada vuelo. Cada vuelo puede aparecer varias veces en el dataset, para
avanzar con nuestro análisis necesitamos quedarnos solo con el último registro de cada
vuelo.
Puedes crear una tabla o vista resultante de esta query en tu base de datos local, la
utilizaremos en los siguientes enunciados. Si prefieres no guardar la última información,
tendrás que hacer uso de esa query como una CTE en los enunciados siguientes.
*/
with last_flight_status as (
	select 
		unique_identifier,
		local_departure, 
		local_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		created_at,
		updated_at,  
		row_number() over(partition by unique_identifier order by updated_at desc) as dr
	   from flights
)
 select
		unique_identifier,
		local_departure, 
		local_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		created_at,
		updated_at
  from last_flight_status
 where dr = 1

/*
Enunciado 5.
Considerando que los campos local_departure y local_actual_departure son necesarios
para el análisis, valida y reconstruye estos valores siguiendo estas reglas:
1.​ Si local_departure es nulo, utiliza created_at.
2.​ Si local_actual_departure es nulo, utiliza local_departure. Si este también es nulo,
utiliza created_at.​
Crea dos nuevos campos:
●​ effective_local_departure
●​ effective_local_actual_departure
Extra:
Realiza las validaciones para los campos local_arrival y local_actual_arrival.
*/

 select 
	flight_row_id,
	unique_identifier,
	created_at,
	local_departure,
	local_actual_departure,
	coalesce(local_departure, created_at) as effective_local_departure,
	coalesce(local_actual_departure, coalesce(local_departure, created_at)) as effective_local_actual_departure,
	local_arrival,
	local_actual_arrival,
	coalesce(local_arrival, created_at) as effective_local_arrival,
	coalesce(local_actual_arrival, coalesce(local_arrival, created_at)) as effective_local_actual_arrival
   from flights
;

/*
Enunciado 6.
Análisis del estado del vuelo. Haciendo uso del resultado del enunciado 4, analiza los
estados de los vuelos.
1.​ Qué estados de vuelo existen
Respuesta:
    CX, DY, EY, NS, OT.
    Además existe hay estados con valor null.
    
2.​ Cuántos vuelos hay por cada estado
    arrival_status	flights_by_status
    CX	              6
    DY	            143
    EY	              9
    NS	              8
    OT	             93
    [NULL]	          7

¿Podrías decir qué significa las siglas de cada estado?
Respuesta: 
    CX=Cancelled
    DY=Delayed
    EY=Early
    NS=No Status 
    OT=On Time
*/

with last_flight_status as (
	select 
		unique_identifier,
		local_departure, 
		local_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		arrival_status,
		created_at,
		updated_at,  
		row_number() over(partition by unique_identifier order by updated_at desc) as dr
	   from flights
)
 select
		arrival_status,
		count(unique_identifier) as flights_by_status
  from last_flight_status
 where dr = 1
 group by arrival_status 
;


/*
Enunciado 7.
País de salida de cada vuelo. Tienes disponible un csv. con información de aeropuertos
airports.csv. Haciendo uso del resultado del enunciado 4, analiza los aeropuertos de salida.
1.​ De qué país despegan los vuelos
Respuesta:
    Italy
    United Kingdom
    Germany
    France
    United States
    Netherlands
    Spain
    * Hay aeropuertos no registrados en la tabla airports, 
      por tanto los paises correspondientes aparecen como null

2.​ Cuántos vuelos despegan por país
Respuesta:
    country	sum_flights_by_country
    [NULL]	        376
    Italy	          8
    United Kingdom	 66
    Germany	         10
    France	         96
    United States	 81
    Netherlands	     88
    Spain	        484
*/

 with depart_airport as (  
	 select 
	 		departure_airport,
		  	count(unique_identifier) as flights_by_country
	   from flights 
   	  group by departure_airport 
)
	 select 
	 		apt.country,
			sum(dep.flights_by_country) sum_flights_by_country
	   from depart_airport as dep
	   left join airports as apt
		 on dep.departure_airport = apt.airport_code 
	  group by apt.country 
;


/*
Enunciado 8.
Delay medio y estado de vuelo por país de salida. Haciendo uso del resultado del enunciado
4, analiza el estado y el delay/retraso medio con el objetivo de identificar si existen países
que pueden presentar problemas operativos en los aeropuertos de salida.
1.​ Cuál es el delay medio por país
Respuesta:
    flights_from_country	avg_delay_by_country 
    France	                 9
    Germany	                 0
    Italy	                -5
    Netherlands	            -1
    Spain	                 7
    United Kingdom	         3
    United States	        12
    N/A	3
*/
with flight_row_number as (  
	 select 
	 		flight_row_id,
	 		unique_identifier,
	 		local_departure,
	 		local_actual_departure,
	 		local_arrival,
	 		local_actual_arrival,
	 		gmt_departure,
	 		gmt_actual_departure,
	 		gmt_arrival,
	 		gmt_actual_arrival,
	 		departure_airport,
	 		arrival_airport,
	 		airline_code,
	 		coalesce(delay_mins, 0) delay_mins,
	 		arrival_status,
	 		created_at,
	 		updated_at,
	 		row_number() over (partition by unique_identifier order by flight_row_id desc) as rn
	   from flights 
),
	last_row_flight as (
	  select departure_airport,
	  		 delay_mins 
		from flight_row_number as frn
	   where rn = 1 
)
  select 
		 coalesce(apt.country, 'N/A') as flights_from_country,
		 round(avg(lrf.delay_mins ), 0) as avg_delay_by_country
	from last_row_flight as lrf
	left join airports as apt
	  on lrf.departure_airport = apt.airport_code 
   group by apt.country

/*
2.​ Cuál es la distribución de estados de vuelos por país.
*/
with flight_row_number as (  
	 select 
	 		flight_row_id,
	 		unique_identifier,
	 		local_departure,
	 		local_actual_departure,
	 		local_arrival,
	 		local_actual_arrival,
	 		gmt_departure,
	 		gmt_actual_departure,
	 		gmt_arrival,
	 		gmt_actual_arrival,
	 		departure_airport,
	 		arrival_airport,
	 		airline_code,
	 		coalesce(delay_mins, 0) delay_mins,
	 		arrival_status,
	 		created_at,
	 		updated_at,
	 		row_number() over (partition by unique_identifier order by flight_row_id desc) as rn
	   from flights 
),
	last_row_flight as (
	  select departure_airport,
	  		 arrival_status ,
	  		 delay_mins 
		from flight_row_number as frn
	   where rn = 1 
)
  select 
		 coalesce(apt.country, 'N/A') as flights_from_country,
		 arrival_status
	from last_row_flight as lrf
	left join airports as apt
	  on lrf.departure_airport = apt.airport_code 
   group by apt.country, lrf.arrival_status
;

/*
Extra:Representa gráficamente la distribución de estados por país. Puedes dibujar un gráfico de
barras o representarlo como creas que mejor se visualiza.
*/

/*
Enunciado 9.
El estado de vuelo por país y por época del año. Dado que no en todas las épocas del año
las condiciones climatólogicas son iguales, analiza si la estaciones del año impactan en el
delay medio por país. Considera la siguiente clasificación de meses del año por época:

- Invierno: diciembre, enero, febrero
- Primavera: marzo, abril, mayo
- Verano: junio, julio, agosto
- Otoño: septiembre, octubre, noviembre​

Respuesta:
Delay medio por país
    flights_from_country	avg_delay_mins
    France	                 9
    Germany	                 0
    Italy	                -5
    N/A	                     3
    Netherlands	            -1
    Spain	                 7
    United Kingdom	         3
    United States	        12
    
Delay medio por país/temporada
    flights_from_country	flight_season	avg_delay_mins
    France	                Invierno	     9
    France	                Otoño	         9
    France	                Primavera	     3
    France	                Verano	        12
    Germany	                Invierno	     0
    Italy	                Verano	        -5
    N/A	                    Invierno	     4
    N/A	                    Otoño	         6
    N/A	                    Primavera	     0
    N/A	                    Verano	         0
    Netherlands	            Invierno	    -1
    Netherlands	            Otoño	         0
    Netherlands	            Primavera	     0
    Netherlands	            Verano	        -3
    Spain		            Invierno	     2
    Spain		            Otoño	         7
    Spain		            Primavera	     9
    Spain		            Verano	        11
    United Kingdom          Invierno	     0
    United Kingdom	        Otoño	         6
    United Kingdom	        Primavera	     2
    United States	        Invierno	    10
    United States	        Otoño	        19
    United States	        Primavera	    12
    United States	        Verano	         3
*/
with flight_row_number as (  
 select 
 		flight_row_id,
 		unique_identifier,
 		coalesce(local_departure, created_at) as local_departure,
 		coalesce(local_actual_departure, coalesce(local_departure)) as local_actual_departure,
 		local_arrival,
 		local_actual_arrival,
 		gmt_departure,
 		gmt_actual_departure,
 		gmt_arrival,
 		gmt_actual_arrival,
 		departure_airport,
 		arrival_airport,
 		airline_code,
 		coalesce(delay_mins, 0) as delay_mins,
 		coalesce(arrival_status, 'N/A') as arrival_status,
 		created_at,
 		updated_at,
 		row_number() over (partition by unique_identifier order by flight_row_id desc) as rn
   from flights 
),	   
last_row_flight as (
  select 
		departure_airport, 
  		arrival_status,
		case 
			when extract(month from local_departure) in (12,  1,  2) then 'Invierno'
			when extract(month from local_departure) in ( 3,  4,  5) then 'Primavera'
			when extract(month from local_departure) in ( 6,  7,  8) then 'Verano'
			when extract(month from local_departure) in ( 9, 10, 11) then 'Otoño'
			else 'N/A'
		end as flight_season,
		delay_mins
	from flight_row_number 
   where rn = 1
)
	select 
			 coalesce(apt.country, 'N/A') as flights_from_country,
			 lrf.flight_season,
			 round(avg(delay_mins), 0) as avg_delay_mins
		from last_row_flight as lrf
		left join airports as apt
		  on lrf.departure_airport = apt.airport_code 
		group by apt.country , lrf.flight_season
		order by 1, 2
;
/*
Enunciado 10.
Frecuencia de actualización de los vuelos. Volviendo al análisis de la calidad del dataset,
explora con qué frecuencia se registran actualizaciones de cada vuelo y 

Respuesta:
    Las actualizaciones se realizan cada 6 horas
*/
	select 
		unique_identifier,
		local_departure, 
		local_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		departure_airport,
		created_at,
		updated_at,
		updated_at - 
		lag(updated_at) over(partition by unique_identifier order by updated_at asc) as update_interval
	   from flights
	  where updated_at is not null
	  order by unique_identifier, updated_at
;

/*
calcula la frecuencia media de actualización por aeropuerto de salida.
*/

with flight_upd_interval as (
	select 
		unique_identifier,
		local_departure, 
		local_actual_departure,
		gmt_arrival,
		gmt_actual_arrival,
		departure_airport,
		created_at,
		updated_at,
		updated_at - 
		lag(updated_at) over(partition by unique_identifier order by updated_at asc) as update_interval
	   from flights
	  where updated_at is not null
	  order by unique_identifier, updated_at
)
 select 
		departure_airport,
		avg(coalesce(update_interval, '0 seconds'::interval))::interval(0)  as avg_upd_freq
   from flight_upd_interval
  group by departure_airport
;

/*
Enunciado 11.
Consistencia del dato. El campo unique_identifier identifica el vuelo y se construye con:
aerolínea, número de vuelo, fecha y aeropuertos. Para cada vuelo (último snapshot),
comprueba si la información del unique_identifier es consistente con las columnas del
dataset.
1.​ Crea un flag is_consistent.
2.​ Calcula cuántos vuelos no son consistentes.
Respuesta:

is_consistent	count
    false	     15
    true	    251
*/
with flight_row_number as (  
	 select 
	 		flight_row_id,
	 		unique_identifier,
	 		local_departure,
	 		local_actual_departure,
	 		local_arrival,
	 		local_actual_arrival,
	 		gmt_departure,
	 		gmt_actual_departure,
	 		gmt_arrival,
	 		gmt_actual_arrival,
	 		departure_airport,
	 		arrival_airport,
	 		airline_code,
	 		delay_mins,
	 		arrival_status,
	 		created_at,
	 		updated_at,
	 		row_number() over (partition by unique_identifier order by flight_row_id desc) as rn
	   from flights 
),
consistent_flights as (
     select 
			unique_identifier,
			airline_code,
			departure_airport,
			arrival_airport,
		 	case 
			 when (left(unique_identifier, 2)::bpchar = airline_code)
			  and (split_part(unique_identifier, '-', 4)::bpchar = departure_airport)
			  and (right(unique_identifier, 3)::bpchar = arrival_airport)
			then 
				true
			else 
				false
			end as is_consistent	 
	   from flight_row_number 
	  where rn = 1
)
	 select 
	 		is_consistent,
	 		count(is_consistent)
	   from consistent_flights
	  group by is_consistent 
	  ;
/*
3.​ Usando la tabla airlines, muestra el nombre de la aerolínea y cuántos vuelos no
consistentes tiene.

Respuesta:

    airline_code	name	count
    IB	            Iberia	15
*/
with flight_row_number as (  
	 select 
	 		flight_row_id,
	 		unique_identifier,
	 		local_departure,
	 		local_actual_departure,
	 		local_arrival,
	 		local_actual_arrival,
	 		gmt_departure,
	 		gmt_actual_departure,
	 		gmt_arrival,
	 		gmt_actual_arrival,
	 		departure_airport,
	 		arrival_airport,
	 		airline_code,
	 		delay_mins,
	 		arrival_status,
	 		created_at,
	 		updated_at,
	 		row_number() over (partition by unique_identifier order by flight_row_id desc) as rn
	   from flights 
),
consistent_flights as (
     select 
			unique_identifier,
			airline_code,
			departure_airport,
			arrival_airport,
		 	case 
			 when (left(unique_identifier, 2)::bpchar = airline_code)
			  and (split_part(unique_identifier, '-', 4)::bpchar = departure_airport)
			  and (right(unique_identifier, 3)::bpchar = arrival_airport)
			then 
				true
			else 
				false
			end as is_consistent	 
	   from flight_row_number 
	  where rn = 1
)
	 select 
	 		cfl.airline_code, 
	 		air.name,
	 		count(cfl.airline_code)
	   from consistent_flights as cfl
	   left join airlines as air
	     on cfl.airline_code = air.airline_code 
	  where cfl.is_consistent  is false
	  group by cfl.airline_code, air."name" 
;
