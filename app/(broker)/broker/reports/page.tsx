import React from 'react';
import { BrokerPlaceholder } from '@/src/components/ui/broker-placeholder';
import { FileText } from 'lucide-react';

export const metadata = {
  title: 'Reports | RMBroker',
  description: 'Trade volume and brokerage performance reports',
};

export default function BrokerReportsPage() {
  return (
    <BrokerPlaceholder
      title="Trade & Commission Reports"
      hindiTitle="व्यापार व कमीशन रिपोर्ट"
      description="Analytical trade volume sheets, brokerage yield reports, counterparty transaction history, and GST-compliant trade exports."
      hindiDescription="व्यापार मात्रा पत्रक, ब्रोकरेज प्राप्ति रिपोर्ट, प्रतिपक्ष लेनदेन इतिहास और जीएसटी-अनुपालन व्यापार रिपोर्ट।"
      milestone="Micro-Sprint RB-07"
      badge="Reports"
      icon={FileText}
    />
  );
}
