import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Toaster } from 'sonner';
import { TooltipProvider } from './components/ui/tooltip';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import Layout from './screens/Layout';
import Curation from './screens/Curation';
import Workspaces from './screens/Workspaces';
import Sources from './screens/Sources';
import StyleProfiles from './screens/StyleProfiles';
import HelpGuide from './screens/HelpGuide';
import Account from './screens/Account';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <TooltipProvider>
          <Toaster position="top-center" richColors theme="system" />
          <Routes>
            <Route path="/" element={<Layout />}>
              <Route index element={<Curation />} />
              <Route path="workspaces" element={<Workspaces />} />
              <Route path="sources" element={<Sources />} />
              <Route path="profiles" element={<StyleProfiles />} />
              <Route path="account" element={<Account />} />
            </Route>
            <Route path="/help" element={<HelpGuide />} />
          </Routes>
        </TooltipProvider>
      </BrowserRouter>
    </QueryClientProvider>
  );
}


