import React from 'react';
import { BrokerPlaceholder } from '@/src/components/ui/broker-placeholder';
import { Bell } from 'lucide-react';

export const metadata = {
  title: 'Notifications | RMBroker',
  description: 'Operational alerts and mandate notifications',
};

export default function BrokerNotificationsPage() {
  return (
    <BrokerPlaceholder
      title="Notifications & Trade Alerts"
      hindiTitle="सूचनाएं व व्यापार अलर्ट"
      description="Real-time multi-channel notifications for deal counter-offers, dispatch status transitions, and urgent mediation updates."
      hindiDescription="सौदा काउंटर ऑफर, प्रेषण स्थिति परिवर्तन और अतिआवश्यक मध्यस्थता अपडेट के लिए वास्तविक समय बहु-चैनल सूचनाएं।"
      milestone="Micro-Sprint RB-08"
      badge="Alerts"
      icon={Bell}
    />
  );
}
