import {
  BrowserRouter,
  Routes,
  Route,
} from "react-router-dom";

import { LandingPage } from "./components/LandingPage";
import EscrowHome from "./components/EscrowHome";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/"
          element={<LandingPage />}
        />

        <Route
          path="/escrow"
          element={<EscrowHome />}
        />
      </Routes>
    </BrowserRouter>
  );
}

export default App;