// فهرست همهٔ موضوع‌هایی که وکیل پرونده‌شان را می‌شناسد، به همان ترتیبی که
// هنگام تشخیص موضوع بررسی می‌شوند. موضوع تازه فقط همین‌جا ثبت می‌شود.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/topics/accused.dart';
import 'package:dastyar/domain/advocate/topics/admin.dart';
import 'package:dastyar/domain/advocate/topics/cheque.dart';
import 'package:dastyar/domain/advocate/topics/child.dart';
import 'package:dastyar/domain/advocate/topics/company.dart';
import 'package:dastyar/domain/advocate/topics/consumer.dart';
import 'package:dastyar/domain/advocate/topics/cyber.dart';
import 'package:dastyar/domain/advocate/topics/debt.dart';
import 'package:dastyar/domain/advocate/topics/enforce.dart';
import 'package:dastyar/domain/advocate/topics/family.dart';
import 'package:dastyar/domain/advocate/topics/guarantee.dart';
import 'package:dastyar/domain/advocate/topics/inherit.dart';
import 'package:dastyar/domain/advocate/topics/injury.dart';
import 'package:dastyar/domain/advocate/topics/labor.dart';
import 'package:dastyar/domain/advocate/topics/marriage.dart';
import 'package:dastyar/domain/advocate/topics/neighbor.dart';
import 'package:dastyar/domain/advocate/topics/partner.dart';
import 'package:dastyar/domain/advocate/topics/property.dart';
import 'package:dastyar/domain/advocate/topics/rent.dart';
import 'package:dastyar/domain/advocate/topics/theft.dart';
import 'package:dastyar/domain/advocate/topics/minor_sale.dart';
import 'package:dastyar/domain/advocate/topics/foreign_contract.dart';

final List<Topic> allTopics = [
  accusedTopic,
  familyTopic,
  laborTopic,
  chequeTopic,
  rentTopic,
  partnerTopic,
  debtTopic,
  neighborTopic,
  adminTopic,
  propertyTopic,
  inheritTopic,
  consumerTopic,
  cyberTopic,
  injuryTopic,
  enforceTopic,
  guaranteeTopic,
  companyTopic,
  childTopic,
  marriageTopic,
  theftTopic,
  minorSaleTopic,
  foreignContractTopic,
];
