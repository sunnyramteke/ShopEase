import 'package:equatable/equatable.dart';

class User extends Equatable{
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String country;

  @override
  List<Object?> get props => [id, name, email, phone, address, city, state, zip, country];


}